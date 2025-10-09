# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Auth::Integration', type: :request do
  let(:user) { create(:user, first_name: 'John', last_name: 'Doe', email: 'john@example.com') }
  let(:company) { create(:company, code: 'TEST123', name: 'Test Company') }
  let(:membership) { create(:membership, user: user, company: company, role: 'admin', scopes: ['products:read']) }

  # Helper to generate JWT token
  def generate_jwt_token(user)
    private_key = OpenSSL::PKey::RSA.new(
      Rails.application.credentials.dig(:doorkeeper, :private_key)
    )

    payload = {
      sub: user.id.to_s,
      exp: 1.hour.from_now.to_i,
      iat: Time.now.to_i
    }

    JWT.encode(payload, private_key, 'RS256')
  end

  before do
    user.update(company: company)
    membership # ensure membership exists
  end

  describe 'GET /auth/check_login' do
    context 'when user is not logged in' do
      it 'redirects with logged_in=false' do
        get '/auth/check_login', params: { return_to: 'http://example.com/callback' }

        expect(response).to redirect_to('http://example.com/callback?logged_in=false')
      end
    end

    context 'when user is logged in' do
      before { sign_in user }

      it 'redirects with logged_in=true' do
        get '/auth/check_login', params: { return_to: 'http://example.com/callback' }

        expect(response).to redirect_to('http://example.com/callback?logged_in=true')
      end
    end

    context 'without return_to parameter' do
      it 'raises an error' do
        expect {
          get '/auth/check_login'
        }.to raise_error(ArgumentError)
      end
    end
  end

  describe 'DELETE /auth/logout' do
    let(:token) { generate_jwt_token(user) }

    context 'with valid token' do
      before do
        create(:oauth_access_token, resource_owner_id: user.id)
      end

      it 'destroys user tokens and redirects' do
        expect {
          delete '/auth/logout', params: {
            token: token,
            return_to: 'http://example.com'
          }
        }.to change { Doorkeeper::AccessToken.where(resource_owner_id: user.id).count }.by(-1)

        expect(response).to redirect_to('http://example.com')
        expect(flash[:notice]).to eq('Logged out successfully')
      end

      it 'signs out current user if matches' do
        sign_in user

        delete '/auth/logout', params: {
          token: token,
          return_to: 'http://example.com'
        }

        expect(controller.current_user).to be_nil
      end
    end

    context 'with invalid token' do
      it 'sets error flash and redirects' do
        delete '/auth/logout', params: {
          token: 'invalid-token',
          return_to: 'http://example.com'
        }

        expect(response).to redirect_to('http://example.com')
        expect(flash[:alert]).to eq('Invalid token')
      end
    end

    context 'without token' do
      it 'redirects without error' do
        delete '/auth/logout', params: { return_to: 'http://example.com' }

        expect(response).to redirect_to('http://example.com')
        expect(flash[:notice]).to be_nil
      end
    end

    context 'without return_to' do
      it 'redirects to root_url' do
        delete '/auth/logout', params: { token: token }

        expect(response).to redirect_to(root_url)
      end
    end
  end

  describe 'GET /auth/logout' do
    let(:token) { generate_jwt_token(user) }

    it 'also supports GET method for redirects' do
      create(:oauth_access_token, resource_owner_id: user.id)

      get '/auth/logout', params: {
        token: token,
        return_to: 'http://example.com'
      }

      expect(response).to redirect_to('http://example.com')
      expect(flash[:notice]).to eq('Logged out successfully')
    end
  end

  describe 'POST /auth/switch_company' do
    let(:token) { generate_jwt_token(user) }
    let(:new_company) { create(:company, code: 'NEWCO', name: 'New Company') }
    let!(:new_membership) { create(:membership, user: user, company: new_company, role: 'member') }

    context 'with valid token and company_code' do
      it 'switches company and returns new token' do
        post '/auth/switch_company', params: {
          token: token,
          company_code: new_company.code,
          return_to: 'http://example.com/callback'
        }

        expect(response).to redirect_to(/company_switched=true/)
        expect(response.location).to include('token=')

        # Verify user's company was updated
        expect(user.reload.company).to eq(new_company)
      end

      it 'generates a new JWT token with new company context' do
        post '/auth/switch_company', params: {
          token: token,
          company_code: new_company.code,
          return_to: 'http://example.com/callback'
        }

        # Extract token from redirect URL
        redirect_uri = URI.parse(response.location)
        query_params = CGI.parse(redirect_uri.query)
        new_token = query_params['token'].first

        # Decode and verify new token
        public_key = OpenSSL::PKey::RSA.new(
          Rails.application.credentials.dig(:doorkeeper, :public_key)
        )
        payload = JWT.decode(new_token, public_key, true, algorithm: 'RS256').first

        expect(payload['sub']).to eq(user.id.to_s)
      end
    end

    context 'with company user does not have access to' do
      let(:unauthorized_company) { create(:company, code: 'NOACCESS') }

      it 'sets error flash and redirects' do
        post '/auth/switch_company', params: {
          token: token,
          company_code: unauthorized_company.code,
          return_to: 'http://example.com'
        }

        expect(response).to redirect_to('http://example.com')
        expect(flash[:alert]).to eq('Company not found or access denied')
      end
    end

    context 'with invalid token' do
      it 'sets error flash and redirects' do
        post '/auth/switch_company', params: {
          token: 'invalid-token',
          company_code: new_company.code,
          return_to: 'http://example.com'
        }

        expect(response).to redirect_to('http://example.com')
        expect(flash[:alert]).to eq('Invalid token')
      end
    end

    context 'without required parameters' do
      it 'sets error flash when token is missing' do
        post '/auth/switch_company', params: {
          company_code: new_company.code,
          return_to: 'http://example.com'
        }

        expect(response).to redirect_to('http://example.com')
        expect(flash[:alert]).to eq('Token and company code are required')
      end

      it 'sets error flash when company_code is missing' do
        post '/auth/switch_company', params: {
          token: token,
          return_to: 'http://example.com'
        }

        expect(response).to redirect_to('http://example.com')
        expect(flash[:alert]).to eq('Token and company code are required')
      end
    end
  end

  describe 'GET /auth/switch_company' do
    let(:token) { generate_jwt_token(user) }
    let(:new_company) { create(:company, code: 'GETCO') }

    before do
      create(:membership, user: user, company: new_company)
    end

    it 'also supports GET method for redirects' do
      get '/auth/switch_company', params: {
        token: token,
        company_code: new_company.code,
        return_to: 'http://example.com/callback'
      }

      expect(response).to redirect_to(/company_switched=true/)
      expect(user.reload.company).to eq(new_company)
    end
  end

  describe 'POST /auth/change_language' do
    let(:token) { generate_jwt_token(user) }

    context 'with valid token and language' do
      it 'updates language in membership info' do
        post '/auth/change_language', params: {
          token: token,
          language: 'fi',
          return_to: 'http://example.com'
        }

        expect(response).to redirect_to('http://example.com')
        expect(flash[:notice]).to eq('Language changed to fi')
        expect(membership.reload.info['language']).to eq('fi')
      end

      it 'initializes info hash if nil' do
        membership.update(info: nil)

        post '/auth/change_language', params: {
          token: token,
          language: 'sv',
          return_to: 'http://example.com'
        }

        expect(membership.reload.info['language']).to eq('sv')
      end
    end

    context 'when user has no membership' do
      before do
        membership.destroy
        user.update(company: nil)
      end

      it 'sets error flash' do
        post '/auth/change_language', params: {
          token: token,
          language: 'fi',
          return_to: 'http://example.com'
        }

        expect(response).to redirect_to('http://example.com')
        expect(flash[:alert]).to eq('No active membership found')
      end
    end

    context 'with invalid token' do
      it 'sets error flash and redirects' do
        post '/auth/change_language', params: {
          token: 'invalid-token',
          language: 'fi',
          return_to: 'http://example.com'
        }

        expect(response).to redirect_to('http://example.com')
        expect(flash[:alert]).to eq('Invalid token')
      end
    end

    context 'without required parameters' do
      it 'sets error flash when token is missing' do
        post '/auth/change_language', params: {
          language: 'fi',
          return_to: 'http://example.com'
        }

        expect(response).to redirect_to('http://example.com')
        expect(flash[:alert]).to eq('Token and language are required')
      end

      it 'sets error flash when language is missing' do
        post '/auth/change_language', params: {
          token: token,
          return_to: 'http://example.com'
        }

        expect(response).to redirect_to('http://example.com')
        expect(flash[:alert]).to eq('Token and language are required')
      end
    end
  end

  describe 'GET /auth/change_language' do
    let(:token) { generate_jwt_token(user) }

    it 'also supports GET method for redirects' do
      get '/auth/change_language', params: {
        token: token,
        language: 'en',
        return_to: 'http://example.com'
      }

      expect(response).to redirect_to('http://example.com')
      expect(flash[:notice]).to eq('Language changed to en')
    end
  end
end
