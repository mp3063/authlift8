# spec/requests/users/registrations_spec.rb
require 'rails_helper'

RSpec.describe 'Users::Registrations', type: :request do
  describe 'GET /users/sign_up' do
    it 'returns http success' do
      get new_user_registration_path
      expect(response).to have_http_status(:success)
    end

    it 'renders the new template' do
      get new_user_registration_path
      expect(response).to render_template(:new)
    end

    context 'when user is already signed in' do
      let(:user) { create(:user) }

      before { sign_in user }

      it 'redirects to root path' do
        get new_user_registration_path
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'POST /users' do
    let(:valid_attributes) do
      {
        email: 'newuser@example.com',
        password: 'password123456',
        password_confirmation: 'password123456',
        first_name: 'New',
        last_name: 'User',
        locale: 'en'
      }
    end

    context 'with valid parameters' do
      it 'creates a new user' do
        expect {
          post user_registration_path, params: { user: valid_attributes }
        }.to change(User, :count).by(1)
      end

      it 'creates a default company for the user' do
        expect {
          post user_registration_path, params: { user: valid_attributes }
        }.to change(Company, :count).by(1)
      end

      it 'creates a membership with owner role' do
        expect {
          post user_registration_path, params: { user: valid_attributes }
        }.to change(Membership, :count).by(1)

        membership = Membership.last
        expect(membership.role).to eq('owner')
        expect(membership.active).to be true
      end

      it 'sets the company as the user current company' do
        post user_registration_path, params: { user: valid_attributes }
        user = User.last
        expect(user.company).to eq(Company.last)
      end

      it 'creates company with correct name format' do
        post user_registration_path, params: { user: valid_attributes }
        company = Company.last
        expect(company.name).to eq("New User's Company")
      end

      it 'signs in the user' do
        post user_registration_path, params: { user: valid_attributes }
        expect(controller.current_user).to be_present
        expect(controller.current_user.email).to eq('newuser@example.com')
      end

      it 'redirects to dashboard' do
        post user_registration_path, params: { user: valid_attributes }
        expect(response).to redirect_to(dashboard_path)
      end

      it 'sets success flash message' do
        post user_registration_path, params: { user: valid_attributes }
        expect(flash[:notice]).to match(/Welcome! You have signed up successfully/i)
      end

      context 'with blank first and last name' do
        let(:attributes_no_name) do
          valid_attributes.merge(first_name: '', last_name: '')
        end

        it 'creates company with email-based name' do
          post user_registration_path, params: { user: attributes_no_name }
          company = Company.last
          expect(company.name).to eq("newuser@example.com's Company")
        end
      end
    end

    context 'with invalid user parameters' do
      let(:invalid_attributes) do
        {
          email: 'invalid_email',
          password: '123',
          password_confirmation: '123',
          first_name: '',
          last_name: ''
        }
      end

      it 'does not create a user' do
        expect {
          post user_registration_path, params: { user: invalid_attributes }
        }.not_to change(User, :count)
      end

      it 'does not create a company' do
        expect {
          post user_registration_path, params: { user: invalid_attributes }
        }.not_to change(Company, :count)
      end

      it 'does not create a membership' do
        expect {
          post user_registration_path, params: { user: invalid_attributes }
        }.not_to change(Membership, :count)
      end

      it 'renders the new template' do
        post user_registration_path, params: { user: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'does not sign in the user' do
        post user_registration_path, params: { user: invalid_attributes }
        expect(controller.current_user).to be_nil
      end
    end

    context 'with duplicate email' do
      let!(:existing_user) { create(:user, email: 'existing@example.com') }

      it 'does not create a user' do
        expect {
          post user_registration_path, params: { user: valid_attributes.merge(email: 'existing@example.com') }
        }.not_to change(User, :count)
      end

      it 'renders the new template with errors' do
        post user_registration_path, params: { user: valid_attributes.merge(email: 'existing@example.com') }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with password mismatch' do
      let(:mismatched_password) do
        valid_attributes.merge(password_confirmation: 'different')
      end

      it 'does not create a user' do
        expect {
          post user_registration_path, params: { user: mismatched_password }
        }.not_to change(User, :count)
      end
    end

    context 'when company creation fails' do
      before do
        failed_company = Company.new(name: 'Test Company', email: 'test@example.com')
        failed_company.errors.add(:name, 'is invalid')
        allow(Company).to receive(:create).and_return(failed_company)
        allow(failed_company).to receive(:persisted?).and_return(false)
        allow(failed_company).to receive(:destroy).and_return(true)
      end

      it 'does not create a user' do
        initial_count = User.count
        post user_registration_path, params: { user: valid_attributes }
        expect(User.count).to eq(initial_count)
      end

      it 'sets alert flash message' do
        post user_registration_path, params: { user: valid_attributes }
        expect(flash[:alert]).to match(/Failed to create company/)
      end
    end

    context 'when membership creation fails' do
      before do
        failed_membership = Membership.new(role: 'owner')
        failed_membership.errors.add(:role, 'is invalid')
        allow(Membership).to receive(:create).and_return(failed_membership)
        allow(failed_membership).to receive(:persisted?).and_return(false)
        allow(failed_membership).to receive(:destroy).and_return(true)
      end

      it 'does not persist user or company' do
        initial_user_count = User.count
        initial_company_count = Company.count

        post user_registration_path, params: { user: valid_attributes }

        expect(User.count).to eq(initial_user_count)
        expect(Company.count).to eq(initial_company_count)
      end

      it 'sets alert flash message' do
        post user_registration_path, params: { user: valid_attributes }
        expect(flash[:alert]).to match(/Failed to create membership/)
      end
    end
  end

  describe 'GET /users/edit' do
    let(:user) { create(:user) }

    before { sign_in user }

    it 'returns http success' do
      get edit_user_registration_path
      expect(response).to have_http_status(:success)
    end

    it 'renders the edit template' do
      get edit_user_registration_path
      expect(response).to render_template(:edit)
    end
  end

  describe 'PUT /users' do
    let(:user) { create(:user, first_name: 'Old', last_name: 'Name') }

    before { sign_in user }

    context 'with valid parameters' do
      let(:update_attributes) do
        {
          first_name: 'Updated',
          last_name: 'Name',
          current_password: 'password123456'
        }
      end

      it 'updates the user' do
        put user_registration_path, params: { user: update_attributes }
        user.reload
        expect(user.first_name).to eq('Updated')
        expect(user.last_name).to eq('Name')
      end

      it 'redirects to dashboard' do
        put user_registration_path, params: { user: update_attributes }
        expect(response).to redirect_to(dashboard_path)
      end

      it 'sets success flash message' do
        put user_registration_path, params: { user: update_attributes }
        expect(flash[:notice]).to match(/Your account has been updated successfully/i)
      end
    end

    context 'with invalid current password' do
      let(:invalid_update) do
        {
          first_name: 'Updated',
          current_password: 'wrongpassword'
        }
      end

      it 'does not update the user' do
        put user_registration_path, params: { user: invalid_update }
        user.reload
        expect(user.first_name).to eq('Old')
      end

      it 'renders the edit template' do
        put user_registration_path, params: { user: invalid_update }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'updating password' do
      let(:password_update) do
        {
          password: 'newpassword123456',
          password_confirmation: 'newpassword123456',
          current_password: 'password123456'
        }
      end

      it 'updates the password' do
        put user_registration_path, params: { user: password_update }
        user.reload
        expect(user.valid_password?('newpassword123456')).to be true
      end
    end
  end

  describe 'DELETE /users' do
    let(:user) { create(:user) }

    before { sign_in user }

    it 'deletes the user account' do
      expect {
        delete user_registration_path
      }.to change(User, :count).by(-1)
    end

    it 'signs out the user' do
      delete user_registration_path
      expect(controller.current_user).to be_nil
    end

    it 'redirects to root path' do
      delete user_registration_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe 'parameter sanitization' do
    it 'permits first_name, last_name, phone, and locale on sign up' do
      post user_registration_path, params: {
        user: {
          email: 'test@example.com',
          password: 'password123456',
          password_confirmation: 'password123456',
          first_name: 'Test',
          last_name: 'User',
          phone: '+1234567890',
          locale: 'es'
        }
      }

      user = User.last
      expect(user.first_name).to eq('Test')
      expect(user.last_name).to eq('User')
      expect(user.phone).to eq('+1234567890')
      expect(user.locale).to eq('es')
    end
  end
end
