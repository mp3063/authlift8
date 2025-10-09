# spec/requests/users/omniauth_callbacks_spec.rb
require 'rails_helper'

RSpec.describe 'Users::OmniauthCallbacks', type: :request do
  before do
    OmniAuth.config.test_mode = true
  end

  after do
    OmniAuth.config.test_mode = false
  end

  describe 'GET /users/auth/google_oauth2/callback' do
    context 'when authentication is successful' do
      let(:auth_hash) do
        OmniAuth::AuthHash.new({
          provider: 'google_oauth2',
          uid: '12345',
          info: {
            email: 'testuser@example.com',
            first_name: 'Test',
            last_name: 'User',
            name: 'Test User'
          },
          credentials: {
            token: 'mock_token',
            expires_at: Time.now.to_i + 3600
          }
        })
      end

      before do
        OmniAuth.config.mock_auth[:google_oauth2] = auth_hash
      end

      context 'for a new user' do
        it 'creates a new user' do
          expect {
            get user_google_oauth2_omniauth_callback_path
          }.to change(User, :count).by(1)
        end

        it 'signs in the user' do
          get user_google_oauth2_omniauth_callback_path
          expect(controller.current_user).to be_present
          expect(controller.current_user.email).to eq('testuser@example.com')
        end

        it 'sets success flash message' do
          get user_google_oauth2_omniauth_callback_path
          expect(flash[:notice]).to match(/Successfully authenticated from Google/i)
        end

        it 'redirects to dashboard' do
          get user_google_oauth2_omniauth_callback_path
          expect(response).to redirect_to(root_path) # Devise default, can be dashboard_path
        end
      end

      context 'for an existing user' do
        let!(:existing_user) { create(:user, email: 'testuser@example.com') }

        it 'does not create a new user' do
          expect {
            get user_google_oauth2_omniauth_callback_path
          }.not_to change(User, :count)
        end

        it 'signs in the existing user' do
          get user_google_oauth2_omniauth_callback_path
          expect(controller.current_user).to eq(existing_user)
        end

        it 'sets success flash message' do
          get user_google_oauth2_omniauth_callback_path
          expect(flash[:notice]).to match(/Successfully authenticated from Google/i)
        end
      end
    end

    context 'when user creation fails' do
      let(:auth_hash) do
        OmniAuth::AuthHash.new({
          provider: 'google_oauth2',
          uid: '12345',
          info: {
            email: 'invalid',  # Invalid email
            name: 'Test User'
          }
        })
      end

      before do
        OmniAuth.config.mock_auth[:google_oauth2] = auth_hash
        allow(User).to receive(:from_omniauth).and_return(User.new(email: 'invalid'))
      end

      it 'redirects to registration page' do
        get user_google_oauth2_omniauth_callback_path
        expect(response).to redirect_to(new_user_registration_path)
      end

      it 'sets alert flash message' do
        get user_google_oauth2_omniauth_callback_path
        expect(flash[:alert]).to match(/Failed to authenticate with Google/i)
      end

      it 'stores oauth data in session' do
        get user_google_oauth2_omniauth_callback_path
        expect(session['devise.oauth_data']).to be_present
      end
    end

    context 'when an error occurs during authentication' do
      before do
        allow(User).to receive(:from_omniauth).and_raise(StandardError.new('Database error'))
      end

      let(:auth_hash) do
        OmniAuth::AuthHash.new({
          provider: 'google_oauth2',
          uid: '12345',
          info: { email: 'testuser@example.com', name: 'Test User' }
        })
      end

      before do
        OmniAuth.config.mock_auth[:google_oauth2] = auth_hash
      end

      it 'redirects to sign in page' do
        get user_google_oauth2_omniauth_callback_path
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'sets alert flash message' do
        get user_google_oauth2_omniauth_callback_path
        expect(flash[:alert]).to match(/An error occurred during Google authentication/i)
      end
    end
  end

  describe 'GET /users/auth/github/callback' do
    context 'when authentication is successful' do
      let(:auth_hash) do
        OmniAuth::AuthHash.new({
          provider: 'github',
          uid: '67890',
          info: {
            email: 'githubuser@example.com',
            name: 'GitHub User',
            first_name: 'GitHub',
            last_name: 'User'
          }
        })
      end

      before do
        OmniAuth.config.mock_auth[:github] = auth_hash
      end

      it 'creates a new user' do
        expect {
          get user_github_omniauth_callback_path
        }.to change(User, :count).by(1)
      end

      it 'signs in the user' do
        get user_github_omniauth_callback_path
        expect(controller.current_user).to be_present
        expect(controller.current_user.email).to eq('githubuser@example.com')
      end

      it 'sets success flash message' do
        get user_github_omniauth_callback_path
        expect(flash[:notice]).to match(/Successfully authenticated from GitHub/i)
      end
    end
  end

  describe 'GET /users/auth/facebook/callback' do
    context 'when authentication is successful' do
      let(:auth_hash) do
        OmniAuth::AuthHash.new({
          provider: 'facebook',
          uid: '11111',
          info: {
            email: 'fbuser@example.com',
            name: 'Facebook User',
            first_name: 'Facebook',
            last_name: 'User'
          }
        })
      end

      before do
        OmniAuth.config.mock_auth[:facebook] = auth_hash
      end

      it 'creates a new user' do
        expect {
          get user_facebook_omniauth_callback_path
        }.to change(User, :count).by(1)
      end

      it 'signs in the user' do
        get user_facebook_omniauth_callback_path
        expect(controller.current_user).to be_present
      end
    end
  end

  describe 'GET /users/auth/twitter/callback' do
    context 'when authentication is successful' do
      let(:auth_hash) do
        OmniAuth::AuthHash.new({
          provider: 'twitter',
          uid: '22222',
          info: {
            email: 'twitteruser@example.com',
            name: 'Twitter User',
            first_name: 'Twitter',
            last_name: 'User'
          }
        })
      end

      before do
        OmniAuth.config.mock_auth[:twitter] = auth_hash
      end

      it 'creates a new user' do
        expect {
          get user_twitter_omniauth_callback_path
        }.to change(User, :count).by(1)
      end

      it 'signs in the user' do
        get user_twitter_omniauth_callback_path
        expect(controller.current_user).to be_present
      end
    end
  end

  describe 'GET /users/auth/failure' do
    it 'redirects to sign in page' do
      get '/users/auth/failure'
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'sets alert flash message with default text' do
      get '/users/auth/failure'
      expect(flash[:alert]).to match(/authentication failed/i)
    end

    context 'with specific error message' do
      it 'includes the error message in flash' do
        get '/users/auth/failure', params: { message: 'access_denied', strategy: 'google_oauth2' }
        expect(flash[:alert]).to match(/Google oauth2 authentication failed: Access denied/i)
      end
    end
  end
end
