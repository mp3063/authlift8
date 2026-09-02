# spec/requests/users/sessions_spec.rb
require 'rails_helper'

RSpec.describe 'Users::Sessions', type: :request do
  let(:user) { create(:user, email: 'testuser@example.com', password: 'password123456') }

  describe 'GET /users/sign_in' do
    it 'returns http success' do
      get new_user_session_path
      expect(response).to have_http_status(:success)
    end

    it 'renders the new template' do
      get new_user_session_path
      expect(response).to render_template(:new)
    end

    context 'when user is already signed in' do
      before { sign_in user }

      it 'redirects to root path' do
        get new_user_session_path
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'POST /users/sign_in' do
    context 'with valid credentials' do
      it 'signs in the user' do
        post user_session_path, params: {
          user: { email: user.email, password: 'password123456' }
        }
        expect(controller.current_user).to eq(user)
      end

      it 'redirects to dashboard' do
        post user_session_path, params: {
          user: { email: user.email, password: 'password123456' }
        }
        expect(response).to redirect_to(dashboard_path)
      end

      it 'sets success flash message' do
        post user_session_path, params: {
          user: { email: user.email, password: 'password123456' }
        }
        expect(flash[:notice]).to match(/Signed in successfully/i)
      end

      it 'updates sign_in_count' do
        expect {
          post user_session_path, params: {
            user: { email: user.email, password: 'password123456' }
          }
        }.to change { user.reload.sign_in_count }.by(1)
      end

      it 'updates current_sign_in_at' do
        expect {
          post user_session_path, params: {
            user: { email: user.email, password: 'password123456' }
          }
        }.to change { user.reload.current_sign_in_at }
      end

      it 'updates last_sign_in_at' do
        user.update(current_sign_in_at: 1.day.ago)
        post user_session_path, params: {
          user: { email: user.email, password: 'password123456' }
        }
        expect(user.reload.last_sign_in_at).to be_present
      end

      context 'with stored location' do
        before do
          # Simulate stored location by visiting a protected page first
          get dashboard_path
        end

        it 'redirects to stored location' do
          post user_session_path, params: {
            user: { email: user.email, password: 'password123456' }
          }
          expect(response).to redirect_to(dashboard_path)
        end
      end

      context 'when arriving from an OAuth authorize request' do
        let(:oauth_app) { create(:oauth_application, redirect_uri: 'http://localhost:3246/auth/callback') }
        let(:authorize_path) do
          oauth_authorization_path(
            client_id: oauth_app.uid,
            redirect_uri: oauth_app.redirect_uri,
            response_type: 'code',
            scope: 'public',
            state: 'abc123'
          )
        end

        it 'redirects back to the authorize request after sign in' do
          get authorize_path
          expect(response).to redirect_to(new_user_session_path)

          post user_session_path, params: {
            user: { email: user.email, password: 'password123456' }
          }
          expect(response).to redirect_to(authorize_path)
        end
      end
    end

    context 'with invalid credentials' do
      it 'does not sign in the user' do
        post user_session_path, params: {
          user: { email: user.email, password: 'wrongpassword' }
        }
        expect(controller.current_user).to be_nil
      end

      it 'renders the new template' do
        post user_session_path, params: {
          user: { email: user.email, password: 'wrongpassword' }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'sets alert flash message' do
        post user_session_path, params: {
          user: { email: user.email, password: 'wrongpassword' }
        }
        expect(flash[:alert]).to match(/Invalid/i)
      end

      it 'does not update sign_in_count' do
        expect {
          post user_session_path, params: {
            user: { email: user.email, password: 'wrongpassword' }
          }
        }.not_to change { user.reload.sign_in_count }
      end
    end

    context 'with missing email' do
      it 'does not sign in the user' do
        post user_session_path, params: {
          user: { email: '', password: 'password123456' }
        }
        expect(controller.current_user).to be_nil
      end
    end

    context 'with missing password' do
      it 'does not sign in the user' do
        post user_session_path, params: {
          user: { email: user.email, password: '' }
        }
        expect(controller.current_user).to be_nil
      end
    end

    context 'with non-existent email' do
      it 'does not sign in any user' do
        post user_session_path, params: {
          user: { email: 'nonexistent@example.com', password: 'password123456' }
        }
        expect(controller.current_user).to be_nil
      end
    end
  end

  describe 'DELETE /users/sign_out' do
    before { sign_in user }

    it 'signs out the user' do
      delete destroy_user_session_path
      expect(controller.current_user).to be_nil
    end

    it 'redirects to sign in page' do
      delete destroy_user_session_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'sets success flash message' do
      delete destroy_user_session_path
      expect(flash[:notice]).to match(/Signed out successfully/i)
    end
  end

  describe 'custom redirect paths' do
    describe '#after_sign_in_path_for' do
      before { sign_in user }

      it 'redirects to dashboard after sign in' do
        post user_session_path, params: {
          user: { email: user.email, password: 'password123456' }
        }
        expect(response).to redirect_to(dashboard_path)
      end
    end

    describe '#after_sign_out_path_for' do
      before { sign_in user }

      it 'redirects to sign in page after sign out' do
        delete destroy_user_session_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
