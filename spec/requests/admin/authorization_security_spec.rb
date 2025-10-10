# spec/requests/admin/authorization_security_spec.rb
require "rails_helper"

RSpec.describe "Admin Authorization Security", type: :request do
  let(:super_admin) { create(:user, super_admin: true) }
  let(:company_a) { create(:company, name: "Company A") }
  let(:company_b) { create(:company, name: "Company B") }
  let(:company_a_admin) { create(:user, email: "admin@companya.com") }
  let(:company_b_admin) { create(:user, email: "admin@companyb.com") }
  let(:regular_user) { create(:user, email: "regular@user.com") }

  before do
    # Setup memberships
    create(:membership, user: company_a_admin, company: company_a, role: "admin", active: true)
    create(:membership, user: company_b_admin, company: company_b, role: "owner", active: true)
    create(:membership, user: regular_user, company: company_a, role: "member", active: true)
  end

  describe "Admin::CompaniesController" do
    context "when company admin tries to access another company" do
      before { sign_in company_a_admin }

      it "denies access to show action" do
        get admin_company_path(company_b)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Access denied. You can only manage your own company.")
      end

      it "denies access to edit action" do
        get edit_admin_company_path(company_b)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Access denied. You can only manage your own company.")
      end

      it "denies access to update action" do
        patch admin_company_path(company_b), params: { company: { name: "Hacked" } }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Access denied. You can only manage your own company.")
      end

      it "denies access to destroy action" do
        delete admin_company_path(company_b)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Access denied. You can only manage your own company.")
      end

      it "logs security warning for unauthorized access attempt" do
        allow(Rails.logger).to receive(:warn).and_call_original

        get admin_company_path(company_b)

        expect(Rails.logger).to have_received(:warn).with(
          /SECURITY: Unauthorized company access attempt/
        )
      end
    end

    context "when company admin accesses their own company" do
      before { sign_in company_a_admin }

      it "allows access to show action" do
        get admin_company_path(company_a)
        expect(response).to have_http_status(:success)
      end

      it "allows access to edit action" do
        get edit_admin_company_path(company_a)
        expect(response).to have_http_status(:success)
      end

      it "allows update action" do
        patch admin_company_path(company_a), params: {
          company: { name: "Updated Company A" }
        }
        expect(response).to redirect_to(admin_company_path(company_a))
        expect(company_a.reload.name).to eq("Updated Company A")
      end
    end

    context "when super admin accesses any company" do
      before { sign_in super_admin }

      it "allows access to any company" do
        get admin_company_path(company_b)
        expect(response).to have_http_status(:success)

        get admin_company_path(company_a)
        expect(response).to have_http_status(:success)
      end
    end

    context "when listing companies" do
      before { sign_in company_a_admin }

      it "only shows companies the admin manages" do
        get admin_companies_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Company A")
        expect(response.body).not_to include("Company B")
      end
    end

    context "when regular user tries to access admin area" do
      before { sign_in regular_user }

      it "denies access to admin area" do
        get admin_companies_path
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Access denied. Admin privileges required.")
      end
    end
  end

  describe "Admin::MembershipsController" do
    let(:company_a_user) { create(:user, email: "user@companya.com") }
    let!(:company_a_membership) { create(:membership, user: company_a_user, company: company_a, active: true) }

    context "when company admin tries to manage another company's memberships" do
      before { sign_in company_a_admin }

      it "denies access to memberships index" do
        get admin_company_memberships_path(company_b)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Access denied. You can only manage your own company.")
      end

      it "logs security warning for unauthorized access" do
        allow(Rails.logger).to receive(:warn).and_call_original

        get admin_company_memberships_path(company_b)

        expect(Rails.logger).to have_received(:warn).with(
          /SECURITY: Unauthorized company access attempt/
        )
      end
    end

    context "when company admin manages their own company's memberships" do
      before { sign_in company_a_admin }

      it "allows access to memberships index" do
        get admin_company_memberships_path(company_a)
        expect(response).to have_http_status(:success)
      end

      it "allows creating memberships" do
        new_user = create(:user, email: "newuser@companya.com")

        expect {
          post admin_company_memberships_path(company_a), params: {
            membership: {
              user_id: new_user.id,
              role: "member",
              active: true
            }
          }
        }.to change(Membership, :count).by(1)

        expect(response).to redirect_to(admin_company_memberships_path(company_a))
      end
    end
  end

  describe "Admin::PartnershipsController" do
    context "when company admin tries to manage another company's partnerships" do
      before { sign_in company_a_admin }

      it "denies access to partnerships index" do
        get admin_company_partnerships_path(company_b)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Access denied. You can only manage your own company.")
      end
    end

    context "when company admin manages their own company's partnerships" do
      before { sign_in company_a_admin }

      it "allows access to partnerships index" do
        get admin_company_partnerships_path(company_a)
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "Admin::OauthApplicationsController" do
    let!(:company_a_app) { create(:oauth_application, name: "Company A App", owner: company_a) }
    let!(:company_b_app) { create(:oauth_application, name: "Company B App", owner: company_b) }

    context "when company admin tries to access another company's OAuth app" do
      before { sign_in company_a_admin }

      it "denies access to show action" do
        get admin_oauth_application_path(company_b_app)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Access denied. You can only manage your own company's OAuth applications.")
      end

      it "denies access to edit action" do
        get edit_admin_oauth_application_path(company_b_app)
        expect(response).to redirect_to(root_path)
      end

      it "logs security warning" do
        allow(Rails.logger).to receive(:warn).and_call_original

        get admin_oauth_application_path(company_b_app)

        expect(Rails.logger).to have_received(:warn).with(
          /SECURITY: Unauthorized OAuth application access attempt/
        )
      end
    end

    context "when company admin accesses their own company's OAuth app" do
      before { sign_in company_a_admin }

      it "allows access to show action" do
        get admin_oauth_application_path(company_a_app)
        expect(response).to have_http_status(:success)
      end

      it "allows access to edit action" do
        get edit_admin_oauth_application_path(company_a_app)
        expect(response).to have_http_status(:success)
      end
    end

    context "when listing OAuth applications" do
      before { sign_in company_a_admin }

      it "only shows applications owned by managed companies" do
        get admin_oauth_applications_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Company A App")
        expect(response.body).not_to include("Company B App")
      end
    end
  end

  describe "Admin::UsersController" do
    let(:company_a_user) { create(:user, email: "user@companya.com") }
    let(:company_b_user) { create(:user, email: "user@companyb.com") }

    before do
      create(:membership, user: company_a_user, company: company_a, active: true)
      create(:membership, user: company_b_user, company: company_b, active: true)
    end

    context "when company admin tries to access user from another company" do
      before { sign_in company_a_admin }

      it "denies access to show action" do
        get admin_user_path(company_b_user)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Access denied. You can only manage users in your company.")
      end

      it "denies access to edit action" do
        get edit_admin_user_path(company_b_user)
        expect(response).to redirect_to(root_path)
      end

      it "logs security warning" do
        allow(Rails.logger).to receive(:warn).and_call_original

        get admin_user_path(company_b_user)

        expect(Rails.logger).to have_received(:warn).with(
          /SECURITY: Unauthorized user access attempt/
        )
      end
    end

    context "when company admin accesses user from their company" do
      before { sign_in company_a_admin }

      it "allows access to show action" do
        get admin_user_path(company_a_user)
        expect(response).to have_http_status(:success)
      end

      it "allows access to edit action" do
        get edit_admin_user_path(company_a_user)
        expect(response).to have_http_status(:success)
      end
    end

    context "when listing users" do
      before { sign_in company_a_admin }

      it "only shows users from managed companies" do
        get admin_users_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("user@companya.com")
        expect(response.body).not_to include("user@companyb.com")
      end
    end

    context "when updating users" do
      before { sign_in company_a_admin }

      it "prevents company admin from setting super_admin flag" do
        patch admin_user_path(company_a_user), params: {
          user: {
            first_name: "Updated",
            super_admin: true
          }
        }

        company_a_user.reload
        expect(company_a_user.first_name).to eq("Updated")
        expect(company_a_user.super_admin).to be_falsey
      end
    end

    context "when super admin updates users" do
      before { sign_in super_admin }

      it "allows setting super_admin flag" do
        patch admin_user_path(company_a_user), params: {
          user: {
            super_admin: true
          }
        }

        expect(company_a_user.reload.super_admin).to be_truthy
      end
    end
  end

  describe "Admin::ApiKeysController" do
    let!(:company_a_api_key) { create(:api_key, company: company_a, name: "Company A Key") }
    let!(:company_b_api_key) { create(:api_key, company: company_b, name: "Company B Key") }

    context "when company admin tries to access another company's API key" do
      before { sign_in company_a_admin }

      it "denies access to show action" do
        get admin_api_key_path(company_b_api_key)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Access denied. You can only manage API keys for your own company.")
      end

      it "logs security warning" do
        allow(Rails.logger).to receive(:warn).and_call_original

        get admin_api_key_path(company_b_api_key)

        expect(Rails.logger).to have_received(:warn).with(
          /SECURITY: Unauthorized API key access attempt/
        )
      end
    end

    context "when company admin accesses their own company's API key" do
      before { sign_in company_a_admin }

      it "allows access to show action" do
        get admin_api_key_path(company_a_api_key)
        expect(response).to have_http_status(:success)
      end
    end

    context "when listing API keys" do
      before { sign_in company_a_admin }

      it "only shows API keys from managed companies" do
        get admin_api_keys_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Company A Key")
        expect(response.body).not_to include("Company B Key")
      end
    end

    context "when creating API keys" do
      before { sign_in company_a_admin }

      it "prevents creating API key for another company" do
        post admin_api_keys_path, params: {
          api_key: {
            name: "Malicious Key",
            company_id: company_b.id,
            active: true
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(flash[:alert]).to eq("Access denied. You can only create API keys for your own company.")
      end

      it "allows creating API key for own company" do
        expect {
          post admin_api_keys_path, params: {
            api_key: {
              name: "Legitimate Key",
              company_id: company_a.id,
              active: true
            }
          }
        }.to change(ApiKey, :count).by(1)

        expect(response).to redirect_to(admin_api_key_path(ApiKey.last))
      end
    end
  end

  describe "Admin::DashboardController" do
    context "when company admin views dashboard" do
      before { sign_in company_a_admin }

      it "shows statistics scoped to their companies only" do
        get admin_dashboard_path
        expect(response).to have_http_status(:success)
        expect(assigns(:managed_company_ids)).to eq([ company_a.id ])
      end
    end

    context "when super admin views dashboard" do
      before { sign_in super_admin }

      it "shows platform-wide statistics" do
        get admin_dashboard_path
        expect(response).to have_http_status(:success)
        expect(assigns(:total_companies)).to eq(Company.count)
      end
    end
  end
end
