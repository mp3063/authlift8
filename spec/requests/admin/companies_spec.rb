# spec/requests/admin/companies_spec.rb
require 'rails_helper'

RSpec.describe 'Admin::Companies', type: :request do
  let(:super_admin) { create(:user, :super_admin) }
  let(:regular_user) { create(:user) }

  describe 'GET /admin/companies' do
    context 'when user is super admin' do
      before { sign_in super_admin }

      it 'returns http success' do
        get admin_companies_path
        expect(response).to have_http_status(:success)
      end

      it 'renders the index template' do
        get admin_companies_path
        expect(response).to render_template(:index)
      end

      it 'assigns @companies' do
        create(:company)
        get admin_companies_path
        expect(assigns(:companies)).to be_present
      end

      it 'includes companies with associations' do
        company1 = create(:company)
        company2 = create(:company)
        user = create(:user)
        create(:membership, user: user, company: company1)

        get admin_companies_path
        expect(assigns(:companies)).to include(company1, company2)
      end

      it 'orders companies by name' do
        create(:company, name: 'Zebra Company')
        create(:company, name: 'Alpha Company')

        get admin_companies_path
        companies = assigns(:companies)
        expect(companies.first.name).to start_with('A')
      end

      it 'limits results to 100' do
        create_list(:company, 105)
        get admin_companies_path
        expect(assigns(:companies).count).to eq(100)
      end

      context 'with search parameter' do
        let!(:acme) { create(:company, name: 'ACME Corp', email: 'info@acme.com', code: 'ACME01') }
        let!(:globex) { create(:company, name: 'Globex Inc', email: 'info@globex.com', code: 'GLOB01') }

        it 'filters by name' do
          get admin_companies_path, params: { search: 'ACME' }
          expect(assigns(:companies)).to include(acme)
          expect(assigns(:companies)).not_to include(globex)
        end

        it 'filters by code' do
          get admin_companies_path, params: { search: 'GLOB01' }
          expect(assigns(:companies)).to include(globex)
          expect(assigns(:companies)).not_to include(acme)
        end

        it 'filters by email' do
          get admin_companies_path, params: { search: 'acme.com' }
          expect(assigns(:companies)).to include(acme)
          expect(assigns(:companies)).not_to include(globex)
        end

        it 'is case insensitive' do
          get admin_companies_path, params: { search: 'acme' }
          expect(assigns(:companies)).to include(acme)
        end
      end

      context 'with active_only filter' do
        let!(:active_company) { create(:company, active: true) }
        let!(:inactive_company) { create(:company, active: false) }

        it 'filters to only active companies' do
          get admin_companies_path, params: { active_only: '1' }
          companies = assigns(:companies)
          expect(companies).to include(active_company)
          expect(companies).not_to include(inactive_company)
        end
      end
    end

    context 'when user is not super admin' do
      before { sign_in regular_user }

      it 'redirects to root path' do
        get admin_companies_path
        expect(response).to redirect_to(root_path)
      end

      it 'sets alert flash message' do
        get admin_companies_path
        expect(flash[:alert]).to match(/Access denied/i)
      end
    end

    context 'when user is not authenticated' do
      it 'redirects to sign in' do
        get admin_companies_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET /admin/companies/:id' do
    let(:company) { create(:company) }

    context 'when user is super admin' do
      before { sign_in super_admin }

      it 'returns http success' do
        get admin_company_path(company)
        expect(response).to have_http_status(:success)
      end

      it 'renders the show template' do
        get admin_company_path(company)
        expect(response).to render_template(:show)
      end

      it 'assigns @company' do
        get admin_company_path(company)
        expect(assigns(:company)).to eq(company)
      end

      it 'assigns @memberships' do
        user = create(:user)
        membership = create(:membership, user: user, company: company)

        get admin_company_path(company)
        expect(assigns(:memberships)).to include(membership)
      end

      it 'assigns @oauth_applications' do
        app = create(:oauth_application, owner: company)

        get admin_company_path(company)
        expect(assigns(:oauth_applications)).to include(app)
      end

      it 'assigns @owned_partnerships' do
        partner = create(:company)
        partnership = create(:partnership, partner_owner: company, partner_client: partner)

        get admin_company_path(company)
        expect(assigns(:owned_partnerships)).to include(partnership)
      end

      it 'assigns @client_partnerships' do
        owner = create(:company)
        partnership = create(:partnership, partner_owner: owner, partner_client: company)

        get admin_company_path(company)
        expect(assigns(:client_partnerships)).to include(partnership)
      end

      context 'when company does not exist' do
        it 'redirects to companies index' do
          get admin_company_path(id: 999999)
          expect(response).to redirect_to(admin_companies_path)
        end

        it 'sets alert flash message' do
          get admin_company_path(id: 999999)
          expect(flash[:alert]).to eq('Company not found.')
        end
      end
    end

    context 'when user is not super admin' do
      before { sign_in regular_user }

      it 'redirects to root path' do
        get admin_company_path(company)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'GET /admin/companies/new' do
    context 'when user is super admin' do
      before { sign_in super_admin }

      it 'returns http success' do
        get new_admin_company_path
        expect(response).to have_http_status(:success)
      end

      it 'renders the new template' do
        get new_admin_company_path
        expect(response).to render_template(:new)
      end

      it 'assigns @company' do
        get new_admin_company_path
        expect(assigns(:company)).to be_a_new(Company)
      end
    end
  end

  describe 'POST /admin/companies' do
    context 'when user is super admin' do
      before { sign_in super_admin }

      let(:valid_params) do
        {
          company: {
            name: 'New Company',
            email: 'info@newcompany.com',
            locale: 'en',
            active: true
          }
        }
      end

      context 'with valid parameters' do
        it 'creates a new company' do
          expect {
            post admin_companies_path, params: valid_params
          }.to change(Company, :count).by(1)
        end

        it 'redirects to company show page' do
          post admin_companies_path, params: valid_params
          expect(response).to redirect_to(admin_company_path(Company.last))
        end

        it 'sets success flash message' do
          post admin_companies_path, params: valid_params
          expect(flash[:notice]).to eq('Company was successfully created.')
        end
      end

      context 'with invalid parameters' do
        let(:invalid_params) do
          {
            company: {
              name: '',
              email: 'invalid'
            }
          }
        end

        it 'does not create a company' do
          expect {
            post admin_companies_path, params: invalid_params
          }.not_to change(Company, :count)
        end

        it 'renders the new template' do
          post admin_companies_path, params: invalid_params
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'sets alert flash message' do
          post admin_companies_path, params: invalid_params
          expect(flash.now[:alert]).to eq('Failed to create company.')
        end
      end
    end
  end

  describe 'GET /admin/companies/:id/edit' do
    let(:company) { create(:company) }

    context 'when user is super admin' do
      before { sign_in super_admin }

      it 'returns http success' do
        get edit_admin_company_path(company)
        expect(response).to have_http_status(:success)
      end

      it 'renders the edit template' do
        get edit_admin_company_path(company)
        expect(response).to render_template(:edit)
      end

      it 'assigns @company' do
        get edit_admin_company_path(company)
        expect(assigns(:company)).to eq(company)
      end
    end
  end

  describe 'PATCH /admin/companies/:id' do
    let(:company) { create(:company, name: 'Old Name') }

    context 'when user is super admin' do
      before { sign_in super_admin }

      context 'with valid parameters' do
        let(:valid_params) do
          {
            company: {
              name: 'Updated Name',
              email: 'updated@company.com'
            }
          }
        end

        it 'updates the company' do
          patch admin_company_path(company), params: valid_params
          company.reload
          expect(company.name).to eq('Updated Name')
          expect(company.email).to eq('updated@company.com')
        end

        it 'redirects to company show page' do
          patch admin_company_path(company), params: valid_params
          expect(response).to redirect_to(admin_company_path(company))
        end

        it 'sets success flash message' do
          patch admin_company_path(company), params: valid_params
          expect(flash[:notice]).to eq('Company was successfully updated.')
        end
      end

      context 'with invalid parameters' do
        let(:invalid_params) do
          {
            company: {
              name: ''
            }
          }
        end

        it 'does not update the company' do
          patch admin_company_path(company), params: invalid_params
          company.reload
          expect(company.name).to eq('Old Name')
        end

        it 'renders the edit template' do
          patch admin_company_path(company), params: invalid_params
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'sets alert flash message' do
          patch admin_company_path(company), params: invalid_params
          expect(flash.now[:alert]).to eq('Failed to update company.')
        end
      end
    end
  end

  describe 'DELETE /admin/companies/:id' do
    let(:company) { create(:company) }

    context 'when user is super admin' do
      before { sign_in super_admin }

      context 'with no dependencies' do
        it 'deletes the company' do
          company # Ensure company exists
          expect {
            delete admin_company_path(company)
          }.to change(Company, :count).by(-1)
        end

        it 'redirects to companies index' do
          delete admin_company_path(company)
          expect(response).to redirect_to(admin_companies_path)
        end

        it 'sets success flash message' do
          delete admin_company_path(company)
          expect(flash[:notice]).to eq('Company was successfully deleted.')
        end
      end

      context 'with active memberships' do
        let!(:membership) { create(:membership, company: company, active: true) }

        it 'does not delete the company' do
          expect {
            delete admin_company_path(company)
          }.not_to change(Company, :count)
        end

        it 'redirects to company show page' do
          delete admin_company_path(company)
          expect(response).to redirect_to(admin_company_path(company))
        end

        it 'sets alert flash message' do
          delete admin_company_path(company)
          expect(flash[:alert]).to match(/Cannot delete company with active members/)
        end
      end

      context 'with OAuth applications' do
        let!(:oauth_app) { create(:oauth_application, owner: company) }

        it 'does not delete the company' do
          expect {
            delete admin_company_path(company)
          }.not_to change(Company, :count)
        end

        it 'sets alert flash message' do
          delete admin_company_path(company)
          expect(flash[:alert]).to match(/Cannot delete company with OAuth applications/)
        end
      end

      context 'with owned partnerships' do
        let(:partner) { create(:company) }
        let!(:partnership) { create(:partnership, partner_owner: company, partner_client: partner) }

        it 'does not delete the company' do
          expect {
            delete admin_company_path(company)
          }.not_to change(Company, :count)
        end

        it 'sets alert flash message' do
          delete admin_company_path(company)
          expect(flash[:alert]).to match(/Cannot delete company with partnerships/)
        end
      end

      context 'with client partnerships' do
        let(:owner) { create(:company) }
        let!(:partnership) { create(:partnership, partner_owner: owner, partner_client: company) }

        it 'does not delete the company' do
          expect {
            delete admin_company_path(company)
          }.not_to change(Company, :count)
        end

        it 'sets alert flash message' do
          delete admin_company_path(company)
          expect(flash[:alert]).to match(/Cannot delete company with partnerships/)
        end
      end

      context 'with inactive memberships but no other dependencies' do
        let!(:membership) { create(:membership, company: company, active: false) }

        it 'deletes the company' do
          expect {
            delete admin_company_path(company)
          }.to change(Company, :count).by(-1)
        end
      end
    end

    context 'when user is not super admin' do
      before { sign_in regular_user }

      it 'does not delete the company' do
        company # Ensure company exists
        expect {
          delete admin_company_path(company)
        }.not_to change(Company, :count)
      end

      it 'redirects to root path' do
        delete admin_company_path(company)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
