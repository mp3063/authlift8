# spec/requests/admin/partnerships_spec.rb
require 'rails_helper'

RSpec.describe 'Admin::Partnerships', type: :request do
  let(:super_admin) { create(:user, :super_admin) }
  let(:regular_user) { create(:user) }
  let(:company) { create(:company) }
  let(:other_company) { create(:company) }

  describe 'GET /admin/companies/:company_id/partnerships' do
    context 'when user is super admin' do
      before { sign_in super_admin }

      it 'returns http success' do
        get admin_company_partnerships_path(company)
        expect(response).to have_http_status(:success)
      end

      it 'renders the index template' do
        get admin_company_partnerships_path(company)
        expect(response).to render_template(:index)
      end

      it 'assigns owned partnerships' do
        partnership = create(:partnership, partner_owner: company, partner_client: other_company)
        get admin_company_partnerships_path(company)
        expect(assigns(:owned_partnerships)).to include(partnership)
      end

      it 'assigns client partnerships' do
        partnership = create(:partnership, partner_owner: other_company, partner_client: company)
        get admin_company_partnerships_path(company)
        expect(assigns(:client_partnerships)).to include(partnership)
      end

      it 'does not include unrelated partnerships' do
        third_company = create(:company)
        unrelated = create(:partnership, partner_owner: other_company, partner_client: third_company)
        get admin_company_partnerships_path(company)
        expect(assigns(:owned_partnerships)).not_to include(unrelated)
        expect(assigns(:client_partnerships)).not_to include(unrelated)
      end
    end

    context 'when user is company admin' do
      let(:admin_user) { create(:user) }

      before do
        create(:membership, user: admin_user, company: company, role: 'admin', active: true)
        sign_in admin_user
      end

      it 'returns http success' do
        get admin_company_partnerships_path(company)
        expect(response).to have_http_status(:success)
      end
    end

    context 'when user is not admin' do
      before { sign_in regular_user }

      it 'redirects to root path' do
        get admin_company_partnerships_path(company)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user is not authenticated' do
      it 'redirects to sign in' do
        get admin_company_partnerships_path(company)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET /admin/companies/:company_id/partnerships/:id' do
    context 'when user is super admin' do
      before { sign_in super_admin }

      let(:partnership) { create(:partnership, partner_owner: company, partner_client: other_company) }

      it 'returns http success' do
        get admin_company_partnership_path(company, partnership)
        expect(response).to have_http_status(:success)
      end

      it 'renders the show template' do
        get admin_company_partnership_path(company, partnership)
        expect(response).to render_template(:show)
      end

      it 'assigns @partnership' do
        get admin_company_partnership_path(company, partnership)
        expect(assigns(:partnership)).to eq(partnership)
      end

      it 'assigns @partnership_apps' do
        oauth_app = create(:oauth_application, partnerships_allowed: true)
        pa = create(:partnership_app, partnership: partnership, oauth_application: oauth_app)
        get admin_company_partnership_path(company, partnership)
        expect(assigns(:partnership_apps)).to include(pa)
      end

      it 'assigns @available_apps excluding already assigned' do
        assigned_app = create(:oauth_application, partnerships_allowed: true)
        available_app = create(:oauth_application, partnerships_allowed: true)
        non_partnership_app = create(:oauth_application, partnerships_allowed: false)
        create(:partnership_app, partnership: partnership, oauth_application: assigned_app)

        get admin_company_partnership_path(company, partnership)
        expect(assigns(:available_apps)).to include(available_app)
        expect(assigns(:available_apps)).not_to include(assigned_app)
        expect(assigns(:available_apps)).not_to include(non_partnership_app)
      end

      it 'shows partnership when company is the client' do
        client_partnership = create(:partnership, partner_owner: other_company, partner_client: company)
        get admin_company_partnership_path(company, client_partnership)
        expect(response).to have_http_status(:success)
        expect(assigns(:partnership)).to eq(client_partnership)
      end

      it 'returns 404 for partnership not involving this company' do
        third_company = create(:company)
        unrelated = create(:partnership, partner_owner: other_company, partner_client: third_company)
        get admin_company_partnership_path(company, unrelated)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when user is not authenticated' do
      let(:partnership) { create(:partnership, partner_owner: company, partner_client: other_company) }

      it 'redirects to sign in' do
        get admin_company_partnership_path(company, partnership)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET /admin/companies/:company_id/partnerships/new' do
    context 'when user is super admin' do
      before { sign_in super_admin }

      it 'returns http success' do
        get new_admin_company_partnership_path(company)
        expect(response).to have_http_status(:success)
      end

      it 'renders the new template' do
        get new_admin_company_partnership_path(company)
        expect(response).to render_template(:new)
      end

      it 'assigns a new partnership' do
        get new_admin_company_partnership_path(company)
        expect(assigns(:partnership)).to be_a_new(Partnership)
      end

      it 'assigns available companies excluding self and existing partners' do
        existing_partner = create(:company)
        create(:partnership, partner_owner: company, partner_client: existing_partner)
        new_candidate = create(:company)

        get new_admin_company_partnership_path(company)
        expect(assigns(:available_companies)).to include(new_candidate)
        expect(assigns(:available_companies)).not_to include(company)
        expect(assigns(:available_companies)).not_to include(existing_partner)
      end
    end
  end

  describe 'POST /admin/companies/:company_id/partnerships' do
    context 'when user is super admin' do
      before { sign_in super_admin }

      context 'with valid parameters' do
        it 'creates a new partnership' do
          expect {
            post admin_company_partnerships_path(company), params: {
              partnership: { partner_client_id: other_company.id, active: true }
            }
          }.to change(Partnership, :count).by(1)
        end

        it 'sets the owner to the current company' do
          post admin_company_partnerships_path(company), params: {
            partnership: { partner_client_id: other_company.id }
          }
          expect(Partnership.last.partner_owner).to eq(company)
        end

        it 'redirects to partnerships index' do
          post admin_company_partnerships_path(company), params: {
            partnership: { partner_client_id: other_company.id }
          }
          expect(response).to redirect_to(admin_company_partnerships_path(company))
        end

        it 'sets success flash message' do
          post admin_company_partnerships_path(company), params: {
            partnership: { partner_client_id: other_company.id }
          }
          expect(flash[:notice]).to eq('Partnership was successfully created.')
        end
      end

      context 'with invalid parameters' do
        it 'does not create a partnership with self' do
          expect {
            post admin_company_partnerships_path(company), params: {
              partnership: { partner_client_id: company.id }
            }
          }.not_to change(Partnership, :count)
        end

        it 'renders the new template on failure' do
          post admin_company_partnerships_path(company), params: {
            partnership: { partner_client_id: company.id }
          }
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context 'with duplicate partnership' do
        before { create(:partnership, partner_owner: company, partner_client: other_company) }

        it 'does not create a duplicate partnership' do
          expect {
            post admin_company_partnerships_path(company), params: {
              partnership: { partner_client_id: other_company.id }
            }
          }.not_to change(Partnership, :count)
        end
      end
    end
  end

  describe 'GET /admin/companies/:company_id/partnerships/:id/edit' do
    let(:partnership) { create(:partnership, partner_owner: company, partner_client: other_company) }

    context 'when user is super admin' do
      before { sign_in super_admin }

      it 'returns http success' do
        get edit_admin_company_partnership_path(company, partnership)
        expect(response).to have_http_status(:success)
      end

      it 'renders the edit template' do
        get edit_admin_company_partnership_path(company, partnership)
        expect(response).to render_template(:edit)
      end

      it 'assigns @partnership' do
        get edit_admin_company_partnership_path(company, partnership)
        expect(assigns(:partnership)).to eq(partnership)
      end
    end
  end

  describe 'PATCH /admin/companies/:company_id/partnerships/:id' do
    let(:partnership) { create(:partnership, partner_owner: company, partner_client: other_company, active: true, managed_company: false) }

    context 'when user is super admin' do
      before { sign_in super_admin }

      it 'updates active status' do
        patch admin_company_partnership_path(company, partnership), params: {
          partnership: { active: false }
        }
        expect(partnership.reload.active).to be false
      end

      it 'updates managed_company flag' do
        patch admin_company_partnership_path(company, partnership), params: {
          partnership: { managed_company: true }
        }
        expect(partnership.reload.managed_company).to be true
      end

      it 'redirects to partnerships index' do
        patch admin_company_partnership_path(company, partnership), params: {
          partnership: { active: false }
        }
        expect(response).to redirect_to(admin_company_partnerships_path(company))
      end

      it 'sets success flash message' do
        patch admin_company_partnership_path(company, partnership), params: {
          partnership: { active: false }
        }
        expect(flash[:notice]).to eq('Partnership was successfully updated.')
      end
    end
  end

  describe 'DELETE /admin/companies/:company_id/partnerships/:id' do
    let!(:partnership) { create(:partnership, partner_owner: company, partner_client: other_company) }

    context 'when user is super admin' do
      before { sign_in super_admin }

      it 'deletes the partnership' do
        expect {
          delete admin_company_partnership_path(company, partnership)
        }.to change(Partnership, :count).by(-1)
      end

      it 'redirects to partnerships index' do
        delete admin_company_partnership_path(company, partnership)
        expect(response).to redirect_to(admin_company_partnerships_path(company))
      end

      it 'sets success flash message' do
        delete admin_company_partnership_path(company, partnership)
        expect(flash[:notice]).to eq('Partnership was successfully deleted.')
      end

      it 'cascades deletion to partnership apps' do
        oauth_app = create(:oauth_application, partnerships_allowed: true)
        create(:partnership_app, partnership: partnership, oauth_application: oauth_app)
        expect {
          delete admin_company_partnership_path(company, partnership)
        }.to change(PartnershipApp, :count).by(-1)
      end
    end

    context 'when user is not authenticated' do
      it 'redirects to sign in' do
        delete admin_company_partnership_path(company, partnership)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end

RSpec.describe 'Admin::PartnershipApps', type: :request do
  let(:super_admin) { create(:user, :super_admin) }
  let(:regular_user) { create(:user) }
  let(:company) { create(:company) }
  let(:other_company) { create(:company) }
  let(:partnership) { create(:partnership, partner_owner: company, partner_client: other_company) }
  let(:oauth_app) { create(:oauth_application, partnerships_allowed: true) }

  describe 'POST /admin/companies/:company_id/partnerships/:partnership_id/partnership_apps' do
    context 'when user is super admin' do
      before { sign_in super_admin }

      it 'adds an application to the partnership' do
        expect {
          post admin_company_partnership_partnership_apps_path(company, partnership), params: {
            oauth_application_id: oauth_app.id
          }
        }.to change(PartnershipApp, :count).by(1)
      end

      it 'redirects to partnership show page' do
        post admin_company_partnership_partnership_apps_path(company, partnership), params: {
          oauth_application_id: oauth_app.id
        }
        expect(response).to redirect_to(admin_company_partnership_path(company, partnership))
      end

      it 'sets success flash message' do
        post admin_company_partnership_partnership_apps_path(company, partnership), params: {
          oauth_application_id: oauth_app.id
        }
        expect(flash[:notice]).to eq('Application was added to this partnership.')
      end

      it 'rejects duplicate application assignment' do
        create(:partnership_app, partnership: partnership, oauth_application: oauth_app)
        expect {
          post admin_company_partnership_partnership_apps_path(company, partnership), params: {
            oauth_application_id: oauth_app.id
          }
        }.not_to change(PartnershipApp, :count)
      end

      it 'sets alert on duplicate' do
        create(:partnership_app, partnership: partnership, oauth_application: oauth_app)
        post admin_company_partnership_partnership_apps_path(company, partnership), params: {
          oauth_application_id: oauth_app.id
        }
        expect(flash[:alert]).to be_present
      end
    end

    context 'when user is not authenticated' do
      it 'redirects to sign in' do
        post admin_company_partnership_partnership_apps_path(company, partnership), params: {
          oauth_application_id: oauth_app.id
        }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when user is not admin' do
      before { sign_in regular_user }

      it 'redirects to root path' do
        post admin_company_partnership_partnership_apps_path(company, partnership), params: {
          oauth_application_id: oauth_app.id
        }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'DELETE /admin/companies/:company_id/partnerships/:partnership_id/partnership_apps/:id' do
    let!(:partnership_app) { create(:partnership_app, partnership: partnership, oauth_application: oauth_app) }

    context 'when user is super admin' do
      before { sign_in super_admin }

      it 'removes the application from the partnership' do
        expect {
          delete admin_company_partnership_partnership_app_path(company, partnership, partnership_app)
        }.to change(PartnershipApp, :count).by(-1)
      end

      it 'redirects to partnership show page' do
        delete admin_company_partnership_partnership_app_path(company, partnership, partnership_app)
        expect(response).to redirect_to(admin_company_partnership_path(company, partnership))
      end

      it 'sets success flash message' do
        delete admin_company_partnership_partnership_app_path(company, partnership, partnership_app)
        expect(flash[:notice]).to eq('Application was removed from this partnership.')
      end
    end

    context 'when user is not authenticated' do
      it 'redirects to sign in' do
        delete admin_company_partnership_partnership_app_path(company, partnership, partnership_app)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
