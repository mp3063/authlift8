# spec/requests/admin/oauth_applications_spec.rb
require 'rails_helper'

RSpec.describe 'Admin::OauthApplications', type: :request do
  let(:super_admin) { create(:user, :super_admin) }
  let(:regular_user) { create(:user) }
  let(:company) { create(:company) }

  describe 'GET /admin/oauth_applications' do
    context 'when user is super admin' do
      before { sign_in super_admin }

      it 'returns http success' do
        get admin_oauth_applications_path
        expect(response).to have_http_status(:success)
      end

      it 'renders the index template' do
        get admin_oauth_applications_path
        expect(response).to render_template(:index)
      end

      it 'assigns @oauth_applications' do
        create(:oauth_application, owner: company)
        get admin_oauth_applications_path
        expect(assigns(:oauth_applications)).to be_present
      end

      it 'includes OAuth applications with owner' do
        app1 = create(:oauth_application, owner: company)
        app2 = create(:oauth_application, owner: company)

        get admin_oauth_applications_path
        expect(assigns(:oauth_applications)).to include(app1, app2)
      end

      it 'orders applications by name' do
        create(:oauth_application, name: 'Zebra App', owner: company)
        create(:oauth_application, name: 'Alpha App', owner: company)

        get admin_oauth_applications_path
        apps = assigns(:oauth_applications)
        expect(apps.first.name).to start_with('A')
      end

      it 'limits results to 100' do
        create_list(:oauth_application, 105, owner: company)
        get admin_oauth_applications_path
        expect(assigns(:oauth_applications).count).to eq(100)
      end

      context 'with search parameter' do
        let!(:app1) { create(:oauth_application, name: 'Mobile App', uid: 'mobile-123', owner: company) }
        let!(:app2) { create(:oauth_application, name: 'Web App', uid: 'web-456', owner: company) }

        it 'filters by name' do
          get admin_oauth_applications_path, params: { search: 'Mobile' }
          expect(assigns(:oauth_applications)).to include(app1)
          expect(assigns(:oauth_applications)).not_to include(app2)
        end

        it 'filters by uid' do
          get admin_oauth_applications_path, params: { search: 'web-456' }
          expect(assigns(:oauth_applications)).to include(app2)
          expect(assigns(:oauth_applications)).not_to include(app1)
        end

        it 'is case insensitive' do
          get admin_oauth_applications_path, params: { search: 'mobile' }
          expect(assigns(:oauth_applications)).to include(app1)
        end
      end

      context 'with trusted_only filter' do
        let!(:trusted_app) { create(:oauth_application, trusted: true, owner: company) }
        let!(:untrusted_app) { create(:oauth_application, trusted: false, owner: company) }

        it 'filters to only trusted applications' do
          get admin_oauth_applications_path, params: { trusted_only: '1' }
          apps = assigns(:oauth_applications)
          expect(apps).to include(trusted_app)
          expect(apps).not_to include(untrusted_app)
        end
      end

      context 'with partnerships_only filter' do
        let!(:partnership_app) { create(:oauth_application, partnerships_allowed: true, owner: company) }
        let!(:regular_app) { create(:oauth_application, partnerships_allowed: false, owner: company) }

        it 'filters to only partnership-enabled applications' do
          get admin_oauth_applications_path, params: { partnerships_only: '1' }
          apps = assigns(:oauth_applications)
          expect(apps).to include(partnership_app)
          expect(apps).not_to include(regular_app)
        end
      end
    end

    context 'when user is not super admin' do
      before { sign_in regular_user }

      it 'redirects to root path' do
        get admin_oauth_applications_path
        expect(response).to redirect_to(root_path)
      end

      it 'sets alert flash message' do
        get admin_oauth_applications_path
        expect(flash[:alert]).to match(/Access denied/i)
      end
    end

    context 'when user is not authenticated' do
      it 'redirects to sign in' do
        get admin_oauth_applications_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET /admin/oauth_applications/:id' do
    let(:oauth_app) { create(:oauth_application, owner: company) }

    context 'when user is super admin' do
      before { sign_in super_admin }

      it 'returns http success' do
        get admin_oauth_application_path(oauth_app)
        expect(response).to have_http_status(:success)
      end

      it 'renders the show template' do
        get admin_oauth_application_path(oauth_app)
        expect(response).to render_template(:show)
      end

      it 'assigns @oauth_application' do
        get admin_oauth_application_path(oauth_app)
        expect(assigns(:oauth_application)).to eq(oauth_app)
      end

      it 'assigns @access_tokens' do
        user = create(:user)
        token = create(:oauth_access_token, application_id: oauth_app.id, resource_owner_id: user.id)

        get admin_oauth_application_path(oauth_app)
        expect(assigns(:access_tokens)).to include(token)
      end

      it 'limits access tokens to 10' do
        user = create(:user)
        12.times { create(:oauth_access_token, application_id: oauth_app.id, resource_owner_id: user.id) }

        get admin_oauth_application_path(oauth_app)
        expect(assigns(:access_tokens).count).to eq(10)
      end

      it 'assigns @allowed_companies' do
        allowed_company = create(:company)
        oauth_app.companies << allowed_company

        get admin_oauth_application_path(oauth_app)
        expect(assigns(:allowed_companies)).to include(allowed_company)
      end

      context 'when application does not exist' do
        it 'redirects to applications index' do
          get admin_oauth_application_path(id: 999999)
          expect(response).to redirect_to(admin_oauth_applications_path)
        end

        it 'sets alert flash message' do
          get admin_oauth_application_path(id: 999999)
          expect(flash[:alert]).to eq('OAuth application not found.')
        end
      end
    end

    context 'when user is not super admin' do
      before { sign_in regular_user }

      it 'redirects to root path' do
        get admin_oauth_application_path(oauth_app)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'GET /admin/oauth_applications/new' do
    context 'when user is super admin' do
      before { sign_in super_admin }

      it 'returns http success' do
        get new_admin_oauth_application_path
        expect(response).to have_http_status(:success)
      end

      it 'renders the new template' do
        get new_admin_oauth_application_path
        expect(response).to render_template(:new)
      end

      it 'assigns @oauth_application' do
        get new_admin_oauth_application_path
        expect(assigns(:oauth_application)).to be_a_new(Doorkeeper::Application)
      end
    end
  end

  describe 'POST /admin/oauth_applications' do
    context 'when user is super admin' do
      before { sign_in super_admin }

      let(:valid_params) do
        {
          doorkeeper_application: {
            name: 'New App',
            redirect_uri: 'https://example.com/callback',
            scopes: 'read write',
            confidential: true,
            owner_type: 'Company',
            owner_id: company.id
          }
        }
      end

      context 'with valid parameters' do
        it 'creates a new OAuth application' do
          expect {
            post admin_oauth_applications_path, params: valid_params
          }.to change(Doorkeeper::Application, :count).by(1)
        end

        it 'redirects to application show page' do
          post admin_oauth_applications_path, params: valid_params
          expect(response).to redirect_to(admin_oauth_application_path(Doorkeeper::Application.last))
        end

        it 'sets success flash message' do
          post admin_oauth_applications_path, params: valid_params
          expect(flash[:notice]).to eq('OAuth application was successfully created.')
        end
      end

      context 'with invalid parameters' do
        let(:invalid_params) do
          {
            doorkeeper_application: {
              name: '',
              redirect_uri: 'invalid'
            }
          }
        end

        it 'does not create an OAuth application' do
          expect {
            post admin_oauth_applications_path, params: invalid_params
          }.not_to change(Doorkeeper::Application, :count)
        end

        it 'renders the new template' do
          post admin_oauth_applications_path, params: invalid_params
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'sets alert flash message' do
          post admin_oauth_applications_path, params: invalid_params
          expect(flash.now[:alert]).to eq('Failed to create OAuth application.')
        end
      end
    end
  end

  describe 'GET /admin/oauth_applications/:id/edit' do
    let(:oauth_app) { create(:oauth_application, owner: company) }

    context 'when user is super admin' do
      before { sign_in super_admin }

      it 'returns http success' do
        get edit_admin_oauth_application_path(oauth_app)
        expect(response).to have_http_status(:success)
      end

      it 'renders the edit template' do
        get edit_admin_oauth_application_path(oauth_app)
        expect(response).to render_template(:edit)
      end

      it 'assigns @oauth_application' do
        get edit_admin_oauth_application_path(oauth_app)
        expect(assigns(:oauth_application)).to eq(oauth_app)
      end
    end
  end

  describe 'PATCH /admin/oauth_applications/:id' do
    let(:oauth_app) { create(:oauth_application, name: 'Old Name', owner: company) }

    context 'when user is super admin' do
      before { sign_in super_admin }

      context 'with valid parameters' do
        let(:valid_params) do
          {
            doorkeeper_application: {
              name: 'Updated Name',
              trusted: true,
              partnerships_allowed: true
            }
          }
        end

        it 'updates the OAuth application' do
          patch admin_oauth_application_path(oauth_app), params: valid_params
          oauth_app.reload
          expect(oauth_app.name).to eq('Updated Name')
          expect(oauth_app.trusted).to be true
          expect(oauth_app.partnerships_allowed).to be true
        end

        it 'redirects to application show page' do
          patch admin_oauth_application_path(oauth_app), params: valid_params
          expect(response).to redirect_to(admin_oauth_application_path(oauth_app))
        end

        it 'sets success flash message' do
          patch admin_oauth_application_path(oauth_app), params: valid_params
          expect(flash[:notice]).to eq('OAuth application was successfully updated.')
        end
      end

      context 'with invalid parameters' do
        let(:invalid_params) do
          {
            doorkeeper_application: {
              name: '',
              redirect_uri: 'invalid'
            }
          }
        end

        it 'does not update the OAuth application' do
          patch admin_oauth_application_path(oauth_app), params: invalid_params
          oauth_app.reload
          expect(oauth_app.name).to eq('Old Name')
        end

        it 'renders the edit template' do
          patch admin_oauth_application_path(oauth_app), params: invalid_params
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'sets alert flash message' do
          patch admin_oauth_application_path(oauth_app), params: invalid_params
          expect(flash.now[:alert]).to eq('Failed to update OAuth application.')
        end
      end
    end
  end

  describe 'DELETE /admin/oauth_applications/:id' do
    let(:oauth_app) { create(:oauth_application, owner: company) }

    context 'when user is super admin' do
      before { sign_in super_admin }

      context 'with no active tokens' do
        it 'deletes the OAuth application' do
          oauth_app # Ensure app exists
          expect {
            delete admin_oauth_application_path(oauth_app)
          }.to change(Doorkeeper::Application, :count).by(-1)
        end

        it 'redirects to applications index' do
          delete admin_oauth_application_path(oauth_app)
          expect(response).to redirect_to(admin_oauth_applications_path)
        end

        it 'sets success flash message' do
          delete admin_oauth_application_path(oauth_app)
          expect(flash[:notice]).to eq('OAuth application was successfully deleted.')
        end
      end

      context 'with active tokens' do
        let(:token_owner) { create(:user) }
        let!(:active_token) do
          create(:oauth_access_token,
                 application_id: oauth_app.id,
                 resource_owner_id: token_owner.id,
                 revoked_at: nil,
                 expires_in: 7200)
        end

        it 'does not delete the OAuth application' do
          expect {
            delete admin_oauth_application_path(oauth_app)
          }.not_to change(Doorkeeper::Application, :count)
        end

        it 'redirects to application show page' do
          delete admin_oauth_application_path(oauth_app)
          expect(response).to redirect_to(admin_oauth_application_path(oauth_app))
        end

        it 'sets alert flash message with token count' do
          delete admin_oauth_application_path(oauth_app)
          expect(flash[:alert]).to match(/Cannot delete application with \d+ active tokens/)
        end
      end

      context 'with revoked tokens only' do
        let(:token_owner) { create(:user) }
        let!(:revoked_token) do
          create(:oauth_access_token,
                 application_id: oauth_app.id,
                 resource_owner_id: token_owner.id,
                 revoked_at: 1.day.ago)
        end

        it 'deletes the OAuth application' do
          expect {
            delete admin_oauth_application_path(oauth_app)
          }.to change(Doorkeeper::Application, :count).by(-1)
        end
      end

      context 'with expired tokens' do
        let(:token_owner) { create(:user) }
        let!(:expired_token) do
          create(:oauth_access_token,
                 application_id: oauth_app.id,
                 resource_owner_id: token_owner.id,
                 created_at: 1.year.ago,
                 expires_in: 7200,
                 revoked_at: nil)
        end

        it 'deletes the OAuth application' do
          expect {
            delete admin_oauth_application_path(oauth_app)
          }.to change(Doorkeeper::Application, :count).by(-1)
        end
      end
    end

    context 'when user is not super admin' do
      before { sign_in regular_user }

      it 'does not delete the OAuth application' do
        oauth_app # Ensure app exists
        expect {
          delete admin_oauth_application_path(oauth_app)
        }.not_to change(Doorkeeper::Application, :count)
      end

      it 'redirects to root path' do
        delete admin_oauth_application_path(oauth_app)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
