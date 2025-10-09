# spec/requests/dashboard_spec.rb
require 'rails_helper'

RSpec.describe 'Dashboard', type: :request do
  let(:user) { create(:user) }
  let(:company) { create(:company) }
  let(:membership) { create(:membership, :owner, user: user, company: company) }

  before do
    membership # Ensure membership exists
    user.update(company: company) # Set current company
  end

  describe 'GET /dashboard' do
    context 'when user is authenticated' do
      before { sign_in user }

      it 'returns http success' do
        get dashboard_path
        expect(response).to have_http_status(:success)
      end

      it 'renders the show template' do
        get dashboard_path
        expect(response).to render_template(:show)
      end

      it 'assigns @user' do
        get dashboard_path
        expect(assigns(:user)).to eq(user)
      end

      it 'assigns @current_company' do
        get dashboard_path
        expect(assigns(:current_company)).to eq(company)
      end

      it 'assigns @current_membership' do
        get dashboard_path
        expect(assigns(:current_membership)).to eq(membership)
      end

      context 'with multiple companies' do
        let(:company2) { create(:company) }
        let(:membership2) { create(:membership, user: user, company: company2) }

        before { membership2 }

        it 'assigns @user_companies with all active memberships' do
          get dashboard_path
          expect(assigns(:user_companies)).to match_array([company, company2])
        end

        it 'orders companies by name' do
          get dashboard_path
          companies = assigns(:user_companies)
          expect(companies.map(&:name)).to eq(companies.map(&:name).sort)
        end
      end

      context 'with OAuth applications' do
        let!(:owned_app) { create(:oauth_application, owner: company) }
        let!(:allowed_app) { create(:oauth_application) }

        before do
          company.allowed_applications << allowed_app
        end

        it 'assigns @owned_applications' do
          get dashboard_path
          expect(assigns(:owned_applications)).to include(owned_app)
        end

        it 'assigns @available_applications' do
          get dashboard_path
          expect(assigns(:available_applications)).to include(allowed_app)
        end
      end

      context 'with partnerships' do
        let!(:supplier_company) { create(:company) }
        let!(:client_company) { create(:company) }
        let!(:supplier_partnership) { create(:partnership, partner_client: company, partner_owner: supplier_company) }
        let!(:client_partnership) { create(:partnership, partner_owner: company, partner_client: client_company) }

        it 'assigns @suppliers' do
          get dashboard_path
          expect(assigns(:suppliers)).to include(supplier_company)
        end

        it 'assigns @clients' do
          get dashboard_path
          expect(assigns(:clients)).to include(client_company)
        end
      end

      context 'with OAuth access tokens' do
        let!(:oauth_app) { create(:oauth_application, owner: company) }
        let!(:token1) { create(:oauth_access_token, application_id: oauth_app.id, resource_owner_id: user.id) }
        let!(:token2) { create(:oauth_access_token, application_id: oauth_app.id, resource_owner_id: user.id) }

        it 'assigns @recent_tokens' do
          get dashboard_path
          expect(assigns(:recent_tokens)).to include(token1, token2)
        end

        it 'limits tokens to 5' do
          6.times { create(:oauth_access_token, application_id: oauth_app.id, resource_owner_id: user.id) }
          get dashboard_path
          expect(assigns(:recent_tokens).count).to eq(5)
        end
      end

      context 'when user has no current company' do
        before do
          membership.update(active: false) # Deactivate membership
          user.update(company: nil)
        end

        it 'returns http success' do
          get dashboard_path
          expect(response).to have_http_status(:success)
        end

        it 'assigns empty arrays for company-dependent data' do
          get dashboard_path
          expect(assigns(:owned_applications)).to eq([])
          expect(assigns(:available_applications)).to eq([])
          expect(assigns(:suppliers)).to eq([])
          expect(assigns(:clients)).to eq([])
          expect(assigns(:recent_tokens)).to eq([])
        end
      end
    end

    context 'when user is not authenticated' do
      it 'redirects to sign in' do
        get dashboard_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET /' do
    context 'when user is authenticated' do
      before { sign_in user }

      it 'returns http success' do
        get root_path
        expect(response).to have_http_status(:success)
      end

      it 'uses the same action as /dashboard' do
        get root_path
        expect(assigns(:user)).to eq(user)
        expect(assigns(:current_company)).to eq(company)
      end
    end
  end
end
