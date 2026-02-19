# frozen_string_literal: true

require "rails_helper"

RSpec.describe "JWT Token Revocation Enforcement", type: :request do
  let(:user) { create(:user) }
  let(:company) { create(:company) }
  let!(:membership) { create(:membership, user: user, company: company, active: true) }
  let(:oauth_app) { create(:oauth_application) }

  let(:private_key) do
    OpenSSL::PKey::RSA.new(
      Rails.application.credentials.dig(:doorkeeper, :private_key)
    )
  end

  # Generate a JWT with a DB-backed access token
  def generate_jwt_with_db_token(user, db_token)
    payload = {
      iss: ENV["AUTHLIFT_URL"],
      sub: user.id.to_s,
      aud: "test-client",
      iat: Time.now.to_i,
      exp: Time.now.to_i + 3600,
      jti: db_token.token
    }

    JWT.encode(payload, private_key, "RS256")
  end

  before do
    user.update!(company: company)
  end

  describe "validate_jwt_token revocation check" do
    it "accepts a valid non-revoked token" do
      db_token = create(:oauth_access_token, application_id: oauth_app.id, resource_owner_id: user.id)
      jwt = generate_jwt_with_db_token(user, db_token)

      delete "/auth/logout", params: { token: jwt, return_to: root_url }

      expect(response).to have_http_status(:see_other)
      expect(flash[:notice]).to eq("Logged out successfully")
    end

    it "rejects a token after it has been revoked" do
      db_token = create(:oauth_access_token, application_id: oauth_app.id, resource_owner_id: user.id)
      jwt = generate_jwt_with_db_token(user, db_token)

      # Revoke the token
      db_token.update_column(:revoked_at, Time.current)

      allow(Rails.logger).to receive(:warn).and_call_original
      allow(Rails.logger).to receive(:error).and_call_original

      delete "/auth/logout", params: { token: jwt, return_to: root_url }

      expect(response).to have_http_status(:see_other)
      expect(flash[:alert]).to eq("Invalid authentication token")
      expect(Rails.logger).to have_received(:warn).with(/SECURITY: Revoked JWT presented/)
    end

    it "rejects a token after destroy_all (logout scenario)" do
      db_token = create(:oauth_access_token, application_id: oauth_app.id, resource_owner_id: user.id)
      jwt = generate_jwt_with_db_token(user, db_token)

      # Simulate another logout destroying all tokens
      user.oauth_access_tokens.destroy_all

      allow(Rails.logger).to receive(:warn).and_call_original
      allow(Rails.logger).to receive(:error).and_call_original

      delete "/auth/logout", params: { token: jwt, return_to: root_url }

      expect(response).to have_http_status(:see_other)
      expect(flash[:alert]).to eq("Invalid authentication token")
      expect(Rails.logger).to have_received(:warn).with(/SECURITY: Revoked JWT presented/)
    end

    it "rejects a token with a jti that does not exist in the database" do
      payload = {
        iss: ENV["AUTHLIFT_URL"],
        sub: user.id.to_s,
        aud: "test-client",
        iat: Time.now.to_i,
        exp: Time.now.to_i + 3600,
        jti: SecureRandom.hex(32)
      }
      jwt = JWT.encode(payload, private_key, "RS256")

      allow(Rails.logger).to receive(:warn).and_call_original
      allow(Rails.logger).to receive(:error).and_call_original

      delete "/auth/logout", params: { token: jwt, return_to: root_url }

      expect(response).to have_http_status(:see_other)
      expect(flash[:alert]).to eq("Invalid authentication token")
      expect(Rails.logger).to have_received(:warn).with(/SECURITY: Revoked JWT presented/)
    end

    it "logs the jti and sub of revoked tokens for incident response" do
      db_token = create(:oauth_access_token, application_id: oauth_app.id, resource_owner_id: user.id)
      jwt = generate_jwt_with_db_token(user, db_token)
      db_token.update_column(:revoked_at, Time.current)

      allow(Rails.logger).to receive(:warn).and_call_original
      allow(Rails.logger).to receive(:error).and_call_original

      delete "/auth/logout", params: { token: jwt, return_to: root_url }

      expect(Rails.logger).to have_received(:warn).with(
        /SECURITY: Revoked JWT presented\. jti=#{Regexp.escape(db_token.token)} sub=#{user.id}/
      )
    end
  end

  describe "revocation across integration endpoints" do
    it "rejects revoked token on switch_company" do
      db_token = create(:oauth_access_token, application_id: oauth_app.id, resource_owner_id: user.id)
      jwt = generate_jwt_with_db_token(user, db_token)
      db_token.update_column(:revoked_at, Time.current)

      post "/auth/switch_company", params: {
        token: jwt,
        company_code: company.code,
        return_to: root_url
      }

      expect(response).to have_http_status(:see_other)
      expect(flash[:alert]).to eq("Invalid authentication token")
    end

    it "rejects revoked token on change_language" do
      db_token = create(:oauth_access_token, application_id: oauth_app.id, resource_owner_id: user.id)
      jwt = generate_jwt_with_db_token(user, db_token)
      db_token.update_column(:revoked_at, Time.current)

      post "/auth/change_language", params: {
        token: jwt,
        language: "en",
        return_to: root_url
      }

      expect(response).to have_http_status(:see_other)
      expect(flash[:alert]).to eq("Invalid authentication token")
    end
  end

  describe "password grant active_for_authentication? check" do
    it "blocks locked users from getting tokens via password grant" do
      user.lock_access!
      oauth_app.update!(confidential: true)

      post "/oauth/token", params: {
        grant_type: "password",
        username: user.email,
        password: "password123456",
        client_id: oauth_app.uid,
        client_secret: oauth_app.secret
      }

      expect(response).to have_http_status(:bad_request)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("invalid_grant")
    end

    it "allows active users to get tokens via password grant" do
      oauth_app.update!(confidential: true)

      post "/oauth/token", params: {
        grant_type: "password",
        username: user.email,
        password: "password123456",
        client_id: oauth_app.uid,
        client_secret: oauth_app.secret
      }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["access_token"]).to be_present
    end
  end
end
