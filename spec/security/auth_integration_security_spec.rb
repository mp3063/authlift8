# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Auth::IntegrationController Security', type: :request do
  # Setup test data
  let(:user) { create(:user) }
  let(:company1) { create(:company, code: 'COMP001') }
  let(:company2) { create(:company, code: 'COMP002') }
  let(:active_membership) { create(:membership, user: user, company: company1, active: true) }
  let(:inactive_membership) { create(:membership, user: user, company: company2, active: false) }

  # JWT helpers for testing
  let(:private_key) do
    OpenSSL::PKey::RSA.new(
      Rails.application.credentials.dig(:doorkeeper, :private_key)
    )
  end

  let(:public_key) do
    OpenSSL::PKey::RSA.new(
      Rails.application.credentials.dig(:doorkeeper, :public_key)
    )
  end

  # Generate a valid JWT token with custom claims
  def generate_jwt(payload_overrides = {})
    default_payload = {
      iss: ENV['AUTHLIFT_URL'],
      sub: user.id.to_s,
      aud: 'test-client',
      iat: Time.now.to_i,
      exp: Time.now.to_i + 3600,
      jti: SecureRandom.hex(32)
    }

    payload = default_payload.merge(payload_overrides)
    JWT.encode(payload, private_key, 'RS256')
  end

  before do
    # Setup active membership for user
    active_membership
    user.update(company: company1)
  end

  describe 'Open Redirect Protection' do
    context 'GET /auth/check_login' do
      it 'allows redirect to whitelisted domain' do
        # Allowed domain from ENV['ALLOWED_ORIGINS']
        allowed_url = "#{ENV.fetch('ALLOWED_ORIGINS', 'http://localhost:3232').split(',').first}?test=1"

        get '/auth/check_login', params: { return_to: allowed_url }

        expect(response).to have_http_status(:see_other)
        expect(response.location).to include('logged_in=')
      end

      it 'allows redirect to relative URLs (safe within domain)' do
        get '/auth/check_login', params: { return_to: '/dashboard' }

        expect(response).to have_http_status(:see_other)
        expect(response.location).to include('/dashboard')
      end

      it 'blocks redirect to non-whitelisted external domain' do
        malicious_url = 'https://evil.com/phishing'

        get '/auth/check_login', params: { return_to: malicious_url }

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['error']).to eq('Invalid redirect URL')
      end

      it 'logs security warning for invalid redirect URL' do
        malicious_url = 'https://evil.com/phishing'

        expect(Rails.logger).to receive(:warn).with(/Invalid redirect URL in check_login/)

        get '/auth/check_login', params: { return_to: malicious_url }
      end

      it 'blocks redirect with invalid URI format' do
        invalid_url = 'http://[invalid'

        get '/auth/check_login', params: { return_to: invalid_url }

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['error']).to eq('Invalid URL format')
      end

      it 'requires return_to parameter' do
        get '/auth/check_login'

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'DELETE /auth/logout' do
      it 'validates redirect URL and defaults to root on invalid URL' do
        token = generate_jwt
        malicious_url = 'https://evil.com/phishing'

        expect(Rails.logger).to receive(:warn).with(/Invalid redirect URL in logout/)

        delete '/auth/logout', params: { token: token, return_to: malicious_url }

        expect(response).to have_http_status(:see_other)
        expect(response.location).to eq(root_url)
      end
    end

    context 'POST /auth/switch_company' do
      it 'validates redirect URL and defaults to root on invalid URL' do
        token = generate_jwt
        malicious_url = 'https://evil.com/phishing'

        expect(Rails.logger).to receive(:warn).with(/Invalid redirect URL in switch_company/)

        post '/auth/switch_company', params: {
          token: token,
          company_code: company1.code,
          return_to: malicious_url
        }

        expect(response).to have_http_status(:see_other)
        expect(response.location).to eq(root_url)
      end
    end

    context 'POST /auth/change_language' do
      it 'validates redirect URL and defaults to root on invalid URL' do
        token = generate_jwt
        malicious_url = 'https://evil.com/phishing'

        expect(Rails.logger).to receive(:warn).with(/Invalid redirect URL in change_language/)

        post '/auth/change_language', params: {
          token: token,
          language: 'en',
          return_to: malicious_url
        }

        expect(response).to have_http_status(:see_other)
        expect(response.location).to eq(root_url)
      end
    end
  end

  describe 'JWT Token Validation' do
    context 'validates JWT claims' do
      it 'accepts token with valid issuer' do
        token = generate_jwt(iss: ENV['AUTHLIFT_URL'])

        delete '/auth/logout', params: { token: token }

        expect(response).to have_http_status(:see_other)
        expect(flash[:notice]).to eq('Logged out successfully')
      end

      it 'rejects token with invalid issuer' do
        wrong_issuer = 'https://evil.com'
        token = generate_jwt(iss: wrong_issuer)

        expect(Rails.logger).to receive(:error).with(/JWT 'iss' claim mismatch/)

        delete '/auth/logout', params: { token: token }

        expect(response).to have_http_status(:see_other)
        expect(flash[:alert]).to eq('Invalid authentication token')
      end

      it 'rejects expired token' do
        # Token expired 1 hour ago
        token = generate_jwt(
          iat: Time.now.to_i - 7200,
          exp: Time.now.to_i - 3600
        )

        expect(Rails.logger).to receive(:error).with(/Expired token during logout/)

        delete '/auth/logout', params: { token: token }

        expect(response).to have_http_status(:see_other)
        expect(flash[:alert]).to eq('Authentication token has expired')
      end

      it 'rejects token with missing subject (sub) claim' do
        payload = {
          iss: ENV['AUTHLIFT_URL'],
          aud: 'test-client',
          iat: Time.now.to_i,
          exp: Time.now.to_i + 3600,
          jti: SecureRandom.hex(32)
          # sub intentionally missing
        }
        token = JWT.encode(payload, private_key, 'RS256')

        expect(Rails.logger).to receive(:error).with(/JWT missing 'sub' claim/)

        delete '/auth/logout', params: { token: token }

        expect(response).to have_http_status(:see_other)
        expect(flash[:alert]).to eq('Invalid authentication token')
      end

      it 'rejects token with future issued at time (iat)' do
        # Token issued 2 hours in the future (beyond clock skew tolerance)
        future_time = Time.now.to_i + 7200
        token = generate_jwt(
          iat: future_time,
          exp: future_time + 3600
        )

        expect(Rails.logger).to receive(:error).with(/JWT 'iat' claim is in the future/)

        delete '/auth/logout', params: { token: token }

        expect(response).to have_http_status(:see_other)
        expect(flash[:alert]).to eq('Invalid authentication token')
      end

      it 'rejects token with future not-before time (nbf)' do
        # Token not valid until 2 hours in the future
        future_time = Time.now.to_i + 7200
        token = generate_jwt(
          nbf: future_time,
          exp: future_time + 3600
        )

        expect(Rails.logger).to receive(:error).with(/JWT 'nbf' claim not yet valid/)

        delete '/auth/logout', params: { token: token }

        expect(response).to have_http_status(:see_other)
        expect(flash[:alert]).to eq('Invalid authentication token')
      end

      it 'accepts token within clock skew tolerance (60 seconds)' do
        # Token issued 30 seconds in the future (within tolerance)
        token = generate_jwt(
          iat: Time.now.to_i + 30
        )

        delete '/auth/logout', params: { token: token }

        expect(response).to have_http_status(:see_other)
        expect(flash[:notice]).to eq('Logged out successfully')
      end

      it 'rejects token signed with wrong key' do
        # Generate a different key pair
        wrong_key = OpenSSL::PKey::RSA.generate(2048)
        payload = {
          iss: ENV['AUTHLIFT_URL'],
          sub: user.id.to_s,
          aud: 'test-client',
          iat: Time.now.to_i,
          exp: Time.now.to_i + 3600,
          jti: SecureRandom.hex(32)
        }
        token = JWT.encode(payload, wrong_key, 'RS256')

        expect(Rails.logger).to receive(:error).with(/JWT decode error during logout/)

        delete '/auth/logout', params: { token: token }

        expect(response).to have_http_status(:see_other)
        expect(flash[:alert]).to eq('Invalid authentication token')
      end
    end
  end

  describe 'Authorization Bypass Prevention - Active Membership Check' do
    context 'POST /auth/switch_company' do
      it 'allows switching to company with active membership' do
        token = generate_jwt

        expect(Rails.logger).to receive(:info).with(
          /User #{user.id} .* switching to company #{company1.id}/
        )

        post '/auth/switch_company', params: {
          token: token,
          company_code: company1.code
        }

        expect(response).to have_http_status(:see_other)
        expect(response.location).to include('token=')
        expect(response.location).to include('company_switched=true')
      end

      it 'blocks switching to company with inactive membership' do
        token = generate_jwt

        expect(Rails.logger).to receive(:warn).with(
          /Unauthorized company switch attempt: user #{user.id} to company #{company2.code}/
        )

        post '/auth/switch_company', params: {
          token: token,
          company_code: company2.code
        }

        expect(response).to have_http_status(:see_other)
        expect(flash[:alert]).to eq('Company not found or access denied')
      end

      it 'blocks switching to non-existent company' do
        token = generate_jwt

        expect(Rails.logger).to receive(:warn).with(
          /Unauthorized company switch attempt: user #{user.id} to company INVALID/
        )

        post '/auth/switch_company', params: {
          token: token,
          company_code: 'INVALID'
        }

        expect(response).to have_http_status(:see_other)
        expect(flash[:alert]).to eq('Company not found or access denied')
      end

      it 'requires both token and company_code parameters' do
        token = generate_jwt

        post '/auth/switch_company', params: { token: token }

        expect(response).to have_http_status(:see_other)
        expect(flash[:alert]).to eq('Token and company code are required')
      end
    end
  end

  describe 'CSRF Protection' do
    context 'POST endpoints require CSRF token or valid JWT' do
      it 'accepts POST with valid JWT token (no CSRF needed)' do
        token = generate_jwt

        post '/auth/switch_company', params: {
          token: token,
          company_code: company1.code
        }

        expect(response).not_to have_http_status(:forbidden)
      end

      it 'rejects POST without JWT or CSRF token' do
        post '/auth/change_language', params: { language: 'en' }

        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['error']).to eq('Invalid authenticity token')
      end

      it 'accepts GET request without CSRF token' do
        get '/auth/check_login', params: { return_to: '/dashboard' }

        expect(response).not_to have_http_status(:forbidden)
      end

      it 'logs CSRF validation failure' do
        expect(Rails.logger).to receive(:error).with(/CSRF validation failed/)

        post '/auth/change_language', params: { language: 'en' }
      end

      it 'falls back to CSRF check when JWT is invalid' do
        invalid_token = 'invalid.jwt.token'

        expect(Rails.logger).to receive(:error).with(/JWT validation failed in CSRF check/)

        post '/auth/change_language', params: {
          token: invalid_token,
          language: 'en'
        }

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'Language Validation Whitelist' do
    context 'POST /auth/change_language' do
      it 'accepts valid language code from whitelist' do
        token = generate_jwt
        valid_languages = %w[en es fr de it pt nl ru ja zh ko ar he tr pl cs sv da fi no]

        valid_languages.each do |lang|
          post '/auth/change_language', params: {
            token: token,
            language: lang
          }

          expect(response).to have_http_status(:see_other)
          expect(flash[:alert]).not_to eq('Invalid language code')
        end
      end

      it 'rejects invalid language code not in whitelist' do
        token = generate_jwt
        invalid_lang = 'xx'

        expect(Rails.logger).to receive(:warn).with(/Invalid language code attempted: #{invalid_lang}/)

        post '/auth/change_language', params: {
          token: token,
          language: invalid_lang
        }

        expect(response).to have_http_status(:see_other)
        expect(flash[:alert]).to eq('Invalid language code')
      end

      it 'rejects SQL injection attempt in language parameter' do
        token = generate_jwt
        sql_injection = "en'; DROP TABLE users; --"

        expect(Rails.logger).to receive(:warn).with(/Invalid language code attempted/)

        post '/auth/change_language', params: {
          token: token,
          language: sql_injection
        }

        expect(response).to have_http_status(:see_other)
        expect(flash[:alert]).to eq('Invalid language code')
      end

      it 'handles language code case-insensitively' do
        token = generate_jwt

        post '/auth/change_language', params: {
          token: token,
          language: 'EN'
        }

        expect(response).to have_http_status(:see_other)
        expect(flash[:notice]).to eq('Language changed to EN')
      end

      it 'updates membership info with validated language' do
        token = generate_jwt

        post '/auth/change_language', params: {
          token: token,
          language: 'es'
        }

        active_membership.reload
        expect(active_membership.info['language']).to eq('es')
      end

      it 'requires both token and language parameters' do
        token = generate_jwt

        post '/auth/change_language', params: { token: token }

        expect(response).to have_http_status(:see_other)
        expect(flash[:alert]).to eq('Token and language are required')
      end
    end
  end

  describe 'Security Logging' do
    it 'logs successful logout' do
      token = generate_jwt

      expect(Rails.logger).to receive(:info).with(
        /Remote logout initiated for user #{user.id} \(#{user.email}\)/
      )

      delete '/auth/logout', params: { token: token }
    end

    it 'logs successful company switch' do
      token = generate_jwt

      expect(Rails.logger).to receive(:info).with(
        /User #{user.id} \(#{user.email}\) switching to company #{company1.id}/
      )

      post '/auth/switch_company', params: {
        token: token,
        company_code: company1.code
      }
    end

    it 'logs successful language change' do
      token = generate_jwt

      expect(Rails.logger).to receive(:info).with(/User #{user.id} changed language to en/)

      post '/auth/change_language', params: {
        token: token,
        language: 'en'
      }
    end

    it 'logs unauthorized company switch attempt' do
      token = generate_jwt

      expect(Rails.logger).to receive(:warn).with(
        /Unauthorized company switch attempt: user #{user.id} to company #{company2.code}/
      )

      post '/auth/switch_company', params: {
        token: token,
        company_code: company2.code
      }
    end
  end

  describe 'Edge Cases and Error Handling' do
    it 'handles user not found gracefully' do
      token = generate_jwt(sub: '99999')

      expect(Rails.logger).to receive(:error).with(/User not found during logout/)

      delete '/auth/logout', params: { token: token }

      expect(response).to have_http_status(:see_other)
      expect(flash[:alert]).to eq('User not found')
    end

    it 'handles missing token parameter' do
      delete '/auth/logout'

      expect(response).to have_http_status(:see_other)
      expect(flash[:alert]).to eq('Authentication token is required')
    end

    it 'handles user with no active membership during language change' do
      # Remove all memberships
      user.memberships.destroy_all
      token = generate_jwt

      expect(Rails.logger).to receive(:warn).with(/No active membership found for user #{user.id}/)

      post '/auth/change_language', params: {
        token: token,
        language: 'en'
      }

      expect(response).to have_http_status(:see_other)
      expect(flash[:alert]).to eq('No active membership found')
    end

    it 'destroys all OAuth tokens on logout' do
      token = generate_jwt

      # Create multiple access tokens
      create(:oauth_access_token, resource_owner_id: user.id)
      create(:oauth_access_token, resource_owner_id: user.id)

      expect(user.oauth_access_tokens.count).to be > 0

      delete '/auth/logout', params: { token: token }

      expect(user.oauth_access_tokens.count).to eq(0)
    end

    it 'generates new JWT with updated company context on switch' do
      token = generate_jwt

      post '/auth/switch_company', params: {
        token: token,
        company_code: company1.code
      }

      # Extract new token from redirect
      expect(response.location).to include('token=')

      # Verify user's company was updated
      user.reload
      expect(user.company).to eq(company1)
    end
  end
end
