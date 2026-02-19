# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Auth::IntegrationController locked account handling", type: :request do
  let(:user) { create(:user) }
  let(:company) { create(:company) }
  let!(:membership) { create(:membership, user: user, company: company, active: true) }
  let(:token) { generate_jwt_token(user) }

  before do
    user.update!(company: company)
    user.lock_access!
  end

  def generate_jwt_token(user)
    private_key = OpenSSL::PKey::RSA.new(
      Rails.application.credentials.dig(:doorkeeper, :private_key)
    )

    payload = {
      sub: user.id.to_s,
      exp: 1.hour.from_now.to_i,
      iat: Time.now.to_i,
      iss: ENV["AUTHLIFT_URL"] || "http://www.example.com"
    }

    JWT.encode(payload, private_key, "RS256")
  end

  describe "DELETE /auth/logout" do
    it "returns 423 Locked for locked account" do
      delete auth_logout_path, params: { token: token, return_to: "http://www.example.com/callback" }

      expect(response).to have_http_status(:locked)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("account_locked")
    end

    it "logs the security event" do
      allow(Rails.logger).to receive(:warn).and_call_original

      delete auth_logout_path, params: { token: token, return_to: "http://www.example.com/callback" }

      expect(Rails.logger).to have_received(:warn).with(
        /Locked account attempted JWT action.*User #{user.id}/
      )
    end
  end

  describe "POST /auth/switch_company" do
    let(:other_company) { create(:company) }
    let!(:other_membership) { create(:membership, user: user, company: other_company, active: true) }

    it "returns 423 Locked for locked account" do
      post auth_switch_company_path, params: {
        token: token,
        company_code: other_company.code,
        return_to: "http://www.example.com/callback"
      }

      expect(response).to have_http_status(:locked)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("account_locked")
    end
  end

  describe "POST /auth/change_language" do
    it "returns 423 Locked for locked account" do
      post auth_change_language_path, params: {
        token: token,
        language: "fr",
        return_to: "http://www.example.com/callback"
      }

      expect(response).to have_http_status(:locked)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("account_locked")
    end
  end

  context "when account is not locked" do
    before { user.unlock_access! }

    it "allows logout to proceed normally" do
      delete auth_logout_path, params: { token: token, return_to: "http://www.example.com/callback" }

      expect(response).not_to have_http_status(:locked)
    end

    it "allows switch_company to proceed normally" do
      other_company = create(:company)
      create(:membership, user: user, company: other_company, active: true)

      post auth_switch_company_path, params: {
        token: token,
        company_code: other_company.code,
        return_to: "http://www.example.com/callback"
      }

      expect(response).not_to have_http_status(:locked)
    end
  end
end
