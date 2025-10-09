# spec/requests/admin/users_spec.rb
require 'rails_helper'

RSpec.describe 'Admin::Users', type: :request do
  let(:super_admin) { create(:user, :super_admin) }
  let(:regular_user) { create(:user) }

  describe 'GET /admin/users' do
    context 'when user is super admin' do
      before { sign_in super_admin }

      it 'returns http success' do
        get admin_users_path
        expect(response).to have_http_status(:success)
      end

      it 'renders the index template' do
        get admin_users_path
        expect(response).to render_template(:index)
      end

      it 'assigns @users' do
        get admin_users_path
        expect(assigns(:users)).to be_present
      end

      it 'includes users with associations' do
        user1 = create(:user)
        user2 = create(:user)
        company = create(:company)
        create(:membership, user: user1, company: company)

        get admin_users_path
        expect(assigns(:users)).to include(user1, user2)
      end

      it 'orders users by created_at desc' do
        older_user = create(:user)
        sleep 0.01
        newer_user = create(:user)

        get admin_users_path
        users = assigns(:users)
        expect(users.first.created_at).to be >= users.last.created_at
      end

      it 'limits results to 100' do
        create_list(:user, 105)
        get admin_users_path
        expect(assigns(:users).count).to eq(100)
      end

      context 'with search parameter' do
        let!(:john) { create(:user, first_name: 'John', last_name: 'Doe', email: 'john@example.com') }
        let!(:jane) { create(:user, first_name: 'Jane', last_name: 'Smith', email: 'jane@example.com') }

        it 'filters by email' do
          get admin_users_path, params: { search: 'john@example.com' }
          expect(assigns(:users)).to include(john)
          expect(assigns(:users)).not_to include(jane)
        end

        it 'filters by first name' do
          get admin_users_path, params: { search: 'Jane' }
          expect(assigns(:users)).to include(jane)
          expect(assigns(:users)).not_to include(john)
        end

        it 'filters by last name' do
          get admin_users_path, params: { search: 'Doe' }
          expect(assigns(:users)).to include(john)
          expect(assigns(:users)).not_to include(jane)
        end

        it 'is case insensitive' do
          get admin_users_path, params: { search: 'JOHN' }
          expect(assigns(:users)).to include(john)
        end
      end

      context 'with super_admins_only filter' do
        let!(:admin1) { create(:user, :super_admin) }
        let!(:admin2) { create(:user, :super_admin) }
        let!(:regular) { create(:user) }

        it 'filters to only super admins' do
          get admin_users_path, params: { super_admins_only: '1' }
          users = assigns(:users)
          expect(users).to include(admin1, admin2)
          expect(users).not_to include(regular)
        end
      end
    end

    context 'when user is not super admin' do
      before { sign_in regular_user }

      it 'redirects to root path' do
        get admin_users_path
        expect(response).to redirect_to(root_path)
      end

      it 'sets alert flash message' do
        get admin_users_path
        expect(flash[:alert]).to match(/Access denied/i)
      end
    end

    context 'when user is not authenticated' do
      it 'redirects to sign in' do
        get admin_users_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET /admin/users/:id' do
    let(:user) { create(:user) }
    let(:company) { create(:company) }
    let!(:membership) { create(:membership, user: user, company: company) }

    context 'when user is super admin' do
      before { sign_in super_admin }

      it 'returns http success' do
        get admin_user_path(user)
        expect(response).to have_http_status(:success)
      end

      it 'renders the show template' do
        get admin_user_path(user)
        expect(response).to render_template(:show)
      end

      it 'assigns @user' do
        get admin_user_path(user)
        expect(assigns(:user)).to eq(user)
      end

      it 'assigns @memberships' do
        get admin_user_path(user)
        expect(assigns(:memberships)).to include(membership)
      end

      it 'assigns @oauth_tokens' do
        app = create(:oauth_application)
        token = create(:oauth_access_token, application_id: app.id, resource_owner_id: user.id)

        get admin_user_path(user)
        expect(assigns(:oauth_tokens)).to include(token)
      end

      context 'when user does not exist' do
        it 'redirects to users index' do
          get admin_user_path(id: 999999)
          expect(response).to redirect_to(admin_users_path)
        end

        it 'sets alert flash message' do
          get admin_user_path(id: 999999)
          expect(flash[:alert]).to eq('User not found.')
        end
      end
    end

    context 'when user is not super admin' do
      before { sign_in regular_user }

      it 'redirects to root path' do
        get admin_user_path(user)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'GET /admin/users/:id/edit' do
    let(:user) { create(:user) }

    context 'when user is super admin' do
      before { sign_in super_admin }

      it 'returns http success' do
        get edit_admin_user_path(user)
        expect(response).to have_http_status(:success)
      end

      it 'renders the edit template' do
        get edit_admin_user_path(user)
        expect(response).to render_template(:edit)
      end

      it 'assigns @user' do
        get edit_admin_user_path(user)
        expect(assigns(:user)).to eq(user)
      end
    end
  end

  describe 'PATCH /admin/users/:id' do
    let(:user) { create(:user, first_name: 'Old', last_name: 'Name') }

    context 'when user is super admin' do
      before { sign_in super_admin }

      context 'with valid parameters' do
        let(:valid_params) do
          {
            user: {
              first_name: 'Updated',
              last_name: 'User',
              super_admin: true
            }
          }
        end

        it 'updates the user' do
          patch admin_user_path(user), params: valid_params
          user.reload
          expect(user.first_name).to eq('Updated')
          expect(user.last_name).to eq('User')
          expect(user.super_admin).to be true
        end

        it 'redirects to user show page' do
          patch admin_user_path(user), params: valid_params
          expect(response).to redirect_to(admin_user_path(user))
        end

        it 'sets success flash message' do
          patch admin_user_path(user), params: valid_params
          expect(flash[:notice]).to eq('User was successfully updated.')
        end
      end

      context 'with invalid parameters' do
        let(:invalid_params) do
          {
            user: {
              email: 'invalid_email'
            }
          }
        end

        it 'does not update the user' do
          patch admin_user_path(user), params: invalid_params
          user.reload
          expect(user.email).not_to eq('invalid_email')
        end

        it 'renders the edit template' do
          patch admin_user_path(user), params: invalid_params
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'sets alert flash message' do
          patch admin_user_path(user), params: invalid_params
          expect(flash.now[:alert]).to eq('Failed to update user.')
        end
      end
    end
  end

  describe 'DELETE /admin/users/:id' do
    let(:user) { create(:user) }

    context 'when user is super admin' do
      before { sign_in super_admin }

      context 'deleting another user' do
        it 'deletes the user' do
          user # Ensure user exists
          expect {
            delete admin_user_path(user)
          }.to change(User, :count).by(-1)
        end

        it 'redirects to users index' do
          delete admin_user_path(user)
          expect(response).to redirect_to(admin_users_path)
        end

        it 'sets success flash message' do
          delete admin_user_path(user)
          expect(flash[:notice]).to eq('User was successfully deleted.')
        end
      end

      context 'attempting to delete self' do
        it 'does not delete the user' do
          expect {
            delete admin_user_path(super_admin)
          }.not_to change(User, :count)
        end

        it 'redirects to users index' do
          delete admin_user_path(super_admin)
          expect(response).to redirect_to(admin_users_path)
        end

        it 'sets alert flash message' do
          delete admin_user_path(super_admin)
          expect(flash[:alert]).to eq('You cannot delete your own account.')
        end
      end

      context 'attempting to delete sole owner of a company' do
        let(:company) { create(:company) }
        let!(:owner_membership) { create(:membership, :owner, user: user, company: company) }

        it 'does not delete the user' do
          expect {
            delete admin_user_path(user)
          }.not_to change(User, :count)
        end

        it 'redirects to user show page' do
          delete admin_user_path(user)
          expect(response).to redirect_to(admin_user_path(user))
        end

        it 'sets alert flash message with company name' do
          delete admin_user_path(user)
          expect(flash[:alert]).to match(/Cannot delete user: sole owner of companies/)
          expect(flash[:alert]).to include(company.name)
        end
      end

      context 'user is owner but not sole owner' do
        let(:company) { create(:company) }
        let(:other_owner) { create(:user) }
        let!(:owner_membership1) { create(:membership, :owner, user: user, company: company) }
        let!(:owner_membership2) { create(:membership, :owner, user: other_owner, company: company) }

        it 'deletes the user' do
          expect {
            delete admin_user_path(user)
          }.to change(User, :count).by(-1)
        end

        it 'sets success flash message' do
          delete admin_user_path(user)
          expect(flash[:notice]).to eq('User was successfully deleted.')
        end
      end
    end

    context 'when user is not super admin' do
      before { sign_in regular_user }

      it 'does not delete the user' do
        user # Ensure user exists
        expect {
          delete admin_user_path(user)
        }.not_to change(User, :count)
      end

      it 'redirects to root path' do
        delete admin_user_path(user)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
