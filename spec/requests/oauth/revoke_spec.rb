# frozen_string_literal: true

require "rails_helper"

# RFC 7009 token revocation. Client apps (Shopify8) call this on logout with the
# JWT access token they hold; the DB row is found through the JWT's jti claim.
RSpec.describe "POST /oauth/revoke", type: :request do
  let(:user) { create(:user) }
  let(:oauth_app) { create(:oauth_application) }
  let(:client_params) { { client_id: oauth_app.uid, client_secret: oauth_app.secret } }
  let!(:db_token) do
    create(:oauth_access_token, application_id: oauth_app.id, resource_owner_id: user.id,
                                refresh_token: SecureRandom.hex(32))
  end

  def jwt_for(db_token)
    private_key = OpenSSL::PKey::RSA.new(Rails.application.credentials.dig(:doorkeeper, :private_key))
    payload = { iss: ENV["AUTHLIFT_URL"], sub: user.id.to_s, aud: oauth_app.uid,
                iat: Time.now.to_i, exp: Time.now.to_i + 3600, jti: db_token.token }
    JWT.encode(payload, private_key, "RS256")
  end

  it "revokes an access token presented as a JWT" do
    post "/oauth/revoke", params: client_params.merge(token: jwt_for(db_token))

    expect(response).to have_http_status(:ok)
    expect(db_token.reload.revoked_at).to be_present
  end

  it "revokes an access token presented as the raw token value" do
    post "/oauth/revoke", params: client_params.merge(token: db_token.token)

    expect(response).to have_http_status(:ok)
    expect(db_token.reload.revoked_at).to be_present
  end

  it "revokes a refresh token" do
    post "/oauth/revoke", params: client_params.merge(token: db_token.refresh_token)

    expect(response).to have_http_status(:ok)
    expect(db_token.reload.revoked_at).to be_present
  end

  it "revokes a refresh token with token_type_hint" do
    post "/oauth/revoke",
         params: client_params.merge(token: db_token.refresh_token, token_type_hint: "refresh_token")

    expect(response).to have_http_status(:ok)
    expect(db_token.reload.revoked_at).to be_present
  end

  it "returns 200 for an unknown token" do
    post "/oauth/revoke", params: client_params.merge(token: "unknown-token")

    expect(response).to have_http_status(:ok)
  end

  it "refuses to revoke another confidential client's token" do
    other_app = create(:oauth_application)

    post "/oauth/revoke", params: { client_id: other_app.uid, client_secret: other_app.secret,
                                    token: jwt_for(db_token) }

    expect(response).to have_http_status(:forbidden)
    expect(db_token.reload.revoked_at).to be_nil
  end
end
