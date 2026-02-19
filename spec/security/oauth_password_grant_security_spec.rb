# frozen_string_literal: true

require "rails_helper"

RSpec.describe "OAuth Password Grant Security", type: :request do
  let(:user) { create(:user) }
  let(:company) { create(:company) }
  let!(:membership) { create(:membership, user: user, company: company, active: true) }
  let(:oauth_app) { create(:oauth_application, confidential: true) }

  before do
    user.update!(company: company)
  end

  def password_grant_params(email: user.email, password: "password123456")
    {
      grant_type: "password",
      username: email,
      password: password,
      client_id: oauth_app.uid,
      client_secret: oauth_app.secret
    }
  end

  describe "security logging on failed password attempts" do
    it "logs failed password attempt with email and IP" do
      allow(Rails.logger).to receive(:warn).and_call_original

      post "/oauth/token", params: password_grant_params(password: "wrong_password")

      expect(response).to have_http_status(:bad_request)
      expect(Rails.logger).to have_received(:warn).with(
        /\[SECURITY\] OAuth password grant failed:.*Email=#{Regexp.escape(user.email)}.*IP=/
      )
    end

    it "does not log when username is blank" do
      allow(Rails.logger).to receive(:warn).and_call_original

      post "/oauth/token", params: password_grant_params(email: "", password: "wrong")

      expect(response).to have_http_status(:bad_request)
      expect(Rails.logger).not_to have_received(:warn).with(
        /\[SECURITY\] OAuth password grant failed/
      )
    end

    it "logs when nonexistent email is used" do
      allow(Rails.logger).to receive(:warn).and_call_original

      post "/oauth/token", params: password_grant_params(email: "nonexistent@example.com")

      expect(response).to have_http_status(:bad_request)
      expect(Rails.logger).to have_received(:warn).with(
        /\[SECURITY\] OAuth password grant failed:.*Email=nonexistent@example.com/
      )
    end
  end

  describe "security logging for inactive/locked users" do
    it "logs blocked attempt for locked user with correct password" do
      user.lock_access!
      allow(Rails.logger).to receive(:warn).and_call_original

      post "/oauth/token", params: password_grant_params

      expect(response).to have_http_status(:bad_request)
      expect(Rails.logger).to have_received(:warn).with(
        /\[SECURITY\] OAuth password grant blocked for inactive user:.*Email=#{Regexp.escape(user.email)}.*Reason=/
      )
    end

    it "includes the inactive_message reason in the log" do
      user.lock_access!
      allow(Rails.logger).to receive(:warn).and_call_original

      post "/oauth/token", params: password_grant_params

      expect(Rails.logger).to have_received(:warn).with(
        /Reason=locked/
      )
    end
  end

  describe "success logging" do
    it "logs successful password grant with user ID and email" do
      allow(Rails.logger).to receive(:info).and_call_original

      post "/oauth/token", params: password_grant_params

      expect(response).to have_http_status(:ok)
      expect(Rails.logger).to have_received(:info).with(
        /\[AUTH\] OAuth password grant success:.*User=#{user.id}.*Email=#{Regexp.escape(user.email)}.*IP=/
      )
    end
  end

  describe "active_for_authentication? enforcement" do
    it "blocks locked users from getting tokens" do
      user.lock_access!

      post "/oauth/token", params: password_grant_params

      expect(response).to have_http_status(:bad_request)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("invalid_grant")
    end

    it "allows active users to get tokens" do
      post "/oauth/token", params: password_grant_params

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["access_token"]).to be_present
    end
  end

  describe "Rack::Attack throttle configuration" do
    it "has per-email throttle configured for password grant" do
      throttle = Rack::Attack.throttles["oauth-password-grant/email"]
      expect(throttle).to be_present
    end

    it "has per-IP throttle configured for password grant" do
      throttle = Rack::Attack.throttles["oauth-password-grant/ip"]
      expect(throttle).to be_present
    end
  end

  describe "Rack::Attack JSON body parsing" do
    it "extracts password grant params from JSON-encoded requests" do
      json_body = { grant_type: "password", username: "test@example.com" }.to_json
      env = Rack::MockRequest.env_for(
        "/oauth/token",
        method: "POST",
        "CONTENT_TYPE" => "application/json",
        input: json_body
      )
      req = Rack::Attack::Request.new(env)

      result = Rack::Attack.oauth_password_grant_params(req)

      expect(result).to be_present
      expect(result[:grant_type]).to eq("password")
      expect(result[:username]).to eq("test@example.com")
    end

    it "extracts password grant params from form-encoded requests" do
      env = Rack::MockRequest.env_for(
        "/oauth/token",
        method: "POST",
        params: { grant_type: "password", username: "test@example.com" }
      )
      req = Rack::Attack::Request.new(env)

      result = Rack::Attack.oauth_password_grant_params(req)

      expect(result).to be_present
      expect(result[:grant_type]).to eq("password")
      expect(result[:username]).to eq("test@example.com")
    end

    it "returns nil for non-password grant types" do
      env = Rack::MockRequest.env_for(
        "/oauth/token",
        method: "POST",
        params: { grant_type: "client_credentials" }
      )
      req = Rack::Attack::Request.new(env)

      result = Rack::Attack.oauth_password_grant_params(req)

      expect(result).to be_nil
    end

    it "returns nil for non-oauth paths" do
      env = Rack::MockRequest.env_for(
        "/users/sign_in",
        method: "POST",
        params: { grant_type: "password", username: "test@example.com" }
      )
      req = Rack::Attack::Request.new(env)

      result = Rack::Attack.oauth_password_grant_params(req)

      expect(result).to be_nil
    end

    it "handles malformed JSON gracefully" do
      env = Rack::MockRequest.env_for(
        "/oauth/token",
        method: "POST",
        "CONTENT_TYPE" => "application/json",
        input: "not valid json{{"
      )
      req = Rack::Attack::Request.new(env)

      result = Rack::Attack.oauth_password_grant_params(req)

      expect(result).to be_nil
    end
  end
end
