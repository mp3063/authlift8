# spec/requests/admin/dashboard_spec.rb
require 'rails_helper'

RSpec.describe 'Admin::Dashboard', type: :request do
  let(:super_admin) { create(:user, :super_admin) }
  let(:regular_user) { create(:user) }

  describe 'GET /admin' do
    context 'when user is super admin' do
      before { sign_in super_admin }

      it 'returns http success' do
        get admin_path
        expect(response).to have_http_status(:success)
      end

      it 'renders the index template' do
        get admin_path
        expect(response).to render_template(:index)
      end

      context 'dashboard statistics' do
        before do
          # Create test data for statistics
          create_list(:user, 5)
          create_list(:company, 3)
          company = create(:company)
          create_list(:oauth_application, 2, owner: company)
        end

        it 'assigns @total_users' do
          get admin_path
          # +1 for super_admin, +5 from list
          expect(assigns(:total_users)).to eq(6)
        end

        it 'assigns @total_companies' do
          get admin_path
          # +1 for company, +3 from list
          expect(assigns(:total_companies)).to eq(4)
        end

        it 'assigns @total_oauth_apps' do
          get admin_path
          expect(assigns(:total_oauth_apps)).to eq(2)
        end
      end

      context 'active tokens count' do
        let(:company) { create(:company) }
        let(:oauth_app) { create(:oauth_application, owner: company) }
        let(:token_user) { create(:user) }

        before do
          # Active token (not revoked)
          create(:oauth_access_token,
                 application_id: oauth_app.id,
                 resource_owner_id: token_user.id,
                 revoked_at: nil)

          # Revoked token (should not count)
          create(:oauth_access_token,
                 application_id: oauth_app.id,
                 resource_owner_id: token_user.id,
                 revoked_at: 1.day.ago)

          # Recently revoked token (should not count)
          create(:oauth_access_token,
                 application_id: oauth_app.id,
                 resource_owner_id: token_user.id,
                 revoked_at: 1.hour.from_now)
        end

        it 'counts only active tokens' do
          get '/admin'
          expect(assigns(:active_tokens)).to eq(2)
        end
      end

      context 'recent activity' do
        before do
          # Create users with different timestamps
          5.times do |i|
            create(:user, created_at: i.days.ago)
          end

          # Create companies with different timestamps
          5.times do |i|
            create(:company, created_at: i.days.ago)
          end

          # Create tokens
          company = create(:company)
          app = create(:oauth_application, owner: company)
          user = create(:user)
          5.times do |i|
            create(:oauth_access_token,
                   application_id: app.id,
                   resource_owner_id: user.id,
                   created_at: i.days.ago)
          end
        end

        it 'assigns @recent_users limited to 10' do
          get admin_path
          expect(assigns(:recent_users).count).to be <= 10
        end

        it 'assigns @recent_users ordered by created_at desc' do
          get admin_path
          recent_users = assigns(:recent_users)
          expect(recent_users.first.created_at).to be >= recent_users.last.created_at
        end

        it 'assigns @recent_companies limited to 10' do
          get admin_path
          expect(assigns(:recent_companies).count).to be <= 10
        end

        it 'assigns @recent_companies ordered by created_at desc' do
          get admin_path
          recent_companies = assigns(:recent_companies)
          expect(recent_companies.first.created_at).to be >= recent_companies.last.created_at
        end

        it 'assigns @recent_tokens limited to 10' do
          get admin_path
          expect(assigns(:recent_tokens).count).to be <= 10
        end

        it 'assigns @recent_tokens ordered by created_at desc' do
          get admin_path
          recent_tokens = assigns(:recent_tokens)
          expect(recent_tokens.first.created_at).to be >= recent_tokens.last.created_at
        end
      end

      context 'with more than 10 recent items' do
        before do
          create_list(:user, 15)
          create_list(:company, 15)

          company = create(:company)
          app = create(:oauth_application, owner: company)
          user = create(:user)
          15.times { create(:oauth_access_token, application_id: app.id, resource_owner_id: user.id) }
        end

        it 'limits recent users to 10' do
          get admin_path
          expect(assigns(:recent_users).count).to eq(10)
        end

        it 'limits recent companies to 10' do
          get admin_path
          expect(assigns(:recent_companies).count).to eq(10)
        end

        it 'limits recent tokens to 10' do
          get admin_path
          expect(assigns(:recent_tokens).count).to eq(10)
        end
      end

      context 'with empty database' do
        before do
          # Only super_admin exists
          User.where.not(id: super_admin.id).destroy_all
          Company.destroy_all
          Doorkeeper::Application.destroy_all
        end

        it 'handles empty statistics gracefully' do
          get admin_path
          expect(assigns(:total_users)).to eq(1) # Just super_admin
          expect(assigns(:total_companies)).to eq(0)
          expect(assigns(:total_oauth_apps)).to eq(0)
          expect(assigns(:active_tokens)).to eq(0)
        end

        it 'handles empty recent activity gracefully' do
          get admin_path
          expect(assigns(:recent_users)).to be_present # Contains super_admin
          expect(assigns(:recent_companies)).to be_empty
          expect(assigns(:recent_tokens)).to be_empty
        end
      end
    end

    context 'when user is not super admin' do
      before { sign_in regular_user }

      it 'redirects to root path' do
        get admin_path
        expect(response).to redirect_to(root_path)
      end

      it 'sets alert flash message' do
        get admin_path
        expect(flash[:alert]).to match(/Access denied/i)
      end

      it 'does not assign statistics' do
        get admin_path
        expect(assigns(:total_users)).to be_nil
      end
    end

    context 'when user is not authenticated' do
      it 'redirects to sign in' do
        get '/admin'
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET /admin/dashboard' do
    context 'when user is super admin' do
      before { sign_in super_admin }

      it 'returns http success' do
        get admin_dashboard_path
        expect(response).to have_http_status(:success)
      end

      it 'uses the same action as /admin' do
        get admin_dashboard_path
        expect(assigns(:total_users)).to be_present
      end
    end
  end
end
