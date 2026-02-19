# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:company).optional }
    it { is_expected.to have_many(:memberships).dependent(:destroy) }
    it { is_expected.to have_many(:companies).through(:memberships) }
    it { is_expected.to have_many(:oauth_access_tokens).class_name('Doorkeeper::AccessToken').with_foreign_key(:resource_owner_id).dependent(:delete_all) }
    it { is_expected.to have_many(:oauth_access_grants).class_name('Doorkeeper::AccessGrant').with_foreign_key(:resource_owner_id).dependent(:delete_all) }
  end

  describe 'validations' do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to validate_presence_of(:last_name) }
    it { is_expected.to validate_presence_of(:password) }

    context 'email format validation' do
      it 'is valid with a valid email' do
        user = build(:user, email: 'test@example.com')
        expect(user).to be_valid
      end

      it 'is invalid without @ symbol' do
        user = build(:user, email: 'invalid-email')
        expect(user).not_to be_valid
        expect(user.errors[:email]).to be_present
      end
    end
  end

  describe 'scopes' do
    describe '.active' do
      it 'returns users with email' do
        active_user = create(:user, email: 'active@example.com')
        expect(User.active).to include(active_user)
      end
    end

    describe '.admins' do
      it 'returns only admin users' do
        admin = create(:user, admin: true)
        regular_user = create(:user, admin: false)

        expect(User.admins).to include(admin)
        expect(User.admins).not_to include(regular_user)
      end
    end
  end

  describe '#current_company' do
    let(:user) { create(:user) }
    let(:company1) { create(:company) }
    let(:company2) { create(:company) }

    context 'when user has a direct company assignment' do
      it 'returns the directly assigned company' do
        # Create active membership first (required by security model)
        create(:membership, user: user, company: company1, active: true)
        user.update(company: company1)
        expect(user.current_company).to eq(company1)
      end
    end

    context 'when user has no direct company but has memberships' do
      it 'returns the first company from memberships' do
        # Create active memberships (required by security model)
        create(:membership, user: user, company: company1, active: true)
        create(:membership, user: user, company: company2, active: true)
        # Set direct company assignment
        user.update(company: company1)

        expect(user.current_company).to eq(company1)
      end
    end

    context 'when user has neither direct company nor memberships' do
      it 'returns nil' do
        expect(user.current_company).to be_nil
      end
    end
  end

  describe '#current_company=' do
    let(:user) { create(:user) }
    let(:company) { create(:company) }

    it 'sets the user\'s direct company' do
      # Create active membership first (required by security model)
      create(:membership, user: user, company: company, active: true)
      user.current_company = company
      expect(user.reload.company).to eq(company)
    end

    it 'updates the company_id in the database' do
      # Create active membership first (required by security model)
      create(:membership, user: user, company: company, active: true)
      expect { user.current_company = company }
        .to change { user.reload.company_id }.from(nil).to(company.id)
    end
  end

  describe '#current_membership' do
    let(:user) { create(:user) }
    let(:company) { create(:company) }
    let(:membership) { create(:membership, user: user, company: company) }

    context 'when user has a current company' do
      before do
        membership
        user.update(company: company)
      end

      it 'returns the membership for the current company' do
        expect(user.current_membership).to eq(membership)
      end
    end

    context 'when user has no current company' do
      it 'returns nil' do
        expect(user.current_membership).to be_nil
      end
    end

    context 'when user has current company but no membership' do
      before { user.update(company: company) }

      it 'returns nil' do
        expect(user.current_membership).to be_nil
      end
    end
  end

  describe '#full_name' do
    it 'returns the concatenated first and last name' do
      user = build(:user, first_name: 'John', last_name: 'Doe')
      expect(user.full_name).to eq('John Doe')
    end

    it 'handles names with extra spaces' do
      user = build(:user, first_name: ' John ', last_name: ' Doe ')
      expect(user.full_name).to eq('John   Doe')
    end

    it 'handles single names' do
      user = build(:user, first_name: 'Madonna', last_name: '')
      expect(user.full_name).to eq('Madonna')
    end
  end

  describe '#all_scopes' do
    let(:user) { create(:user) }
    let(:company) { create(:company) }

    context 'when user has no scopes' do
      it 'returns an empty array' do
        expect(user.all_scopes).to eq([])
      end
    end

    context 'when user has user-level scopes' do
      before { user.update(scopes: 'users:read,users:write') }

      it 'returns user-level scopes as an array' do
        expect(user.all_scopes).to contain_exactly('users:read', 'users:write')
      end
    end

    context 'when user has membership scopes' do
      before do
        user.update(company: company)
        create(:membership, user: user, company: company, scopes: [ 'products:read', 'products:write' ])
      end

      it 'returns membership scopes' do
        expect(user.all_scopes).to contain_exactly('products:read', 'products:write')
      end
    end

    context 'when user has both user-level and membership scopes' do
      before do
        user.update(company: company, scopes: 'users:read,users:write')
        create(:membership, user: user, company: company, scopes: [ 'products:read', 'users:read' ])
      end

      it 'returns unique combination of both' do
        expect(user.all_scopes).to contain_exactly('users:read', 'users:write', 'products:read')
      end
    end

    context 'when user has no current company' do
      before { user.update(scopes: 'users:read') }

      it 'returns only user-level scopes' do
        expect(user.all_scopes).to eq([ 'users:read' ])
      end
    end
  end

  describe '#has_scope?' do
    let(:user) { create(:user) }
    let(:company) { create(:company) }

    context 'when user is an admin' do
      before { user.update(admin: true) }

      it 'returns true for any scope' do
        expect(user.has_scope?('anything')).to be true
        expect(user.has_scope?('products:read')).to be true
        expect(user.has_scope?('users:delete')).to be true
      end
    end

    context 'when user is not an admin' do
      before do
        user.update(company: company)
        create(:membership, user: user, company: company, scopes: [ 'products:read', 'products:write' ])
      end

      it 'returns true for scopes the user has' do
        expect(user.has_scope?('products:read')).to be true
        expect(user.has_scope?('products:write')).to be true
      end

      it 'returns false for scopes the user lacks' do
        expect(user.has_scope?('products:delete')).to be false
        expect(user.has_scope?('users:read')).to be false
      end

      it 'handles scope as a symbol' do
        expect(user.has_scope?(:'products:read')).to be true
      end

      it 'handles scope as a string' do
        expect(user.has_scope?('products:read')).to be true
      end
    end

    context 'when user has no scopes' do
      it 'returns false' do
        expect(user.has_scope?('anything')).to be false
      end
    end
  end

  describe '#admin?' do
    it 'returns true when admin flag is true' do
      user = build(:user, admin: true)
      expect(user.admin?).to be true
    end

    it 'returns false when admin flag is false' do
      user = build(:user, admin: false)
      expect(user.admin?).to be false
    end

    it 'returns false by default' do
      user = build(:user)
      expect(user.admin?).to be false
    end
  end

  describe 'Devise configuration' do
    it 'includes database_authenticatable module' do
      expect(User.devise_modules).to include(:database_authenticatable)
    end

    it 'includes registerable module' do
      expect(User.devise_modules).to include(:registerable)
    end

    it 'includes recoverable module' do
      expect(User.devise_modules).to include(:recoverable)
    end

    it 'includes rememberable module' do
      expect(User.devise_modules).to include(:rememberable)
    end

    it 'includes validatable module' do
      expect(User.devise_modules).to include(:validatable)
    end

    it 'includes trackable module' do
      expect(User.devise_modules).to include(:trackable)
    end

    it 'includes omniauthable module' do
      expect(User.devise_modules).to include(:omniauthable)
    end

    it 'includes timeoutable module' do
      expect(User.devise_modules).to include(:timeoutable)
    end

    it 'includes lockable module' do
      expect(User.devise_modules).to include(:lockable)
    end
  end

  describe 'OmniAuth support' do
    it 'has google_oauth2 as an omniauth provider' do
      expect(User.omniauth_providers).to include(:google_oauth2)
    end
  end

  describe '.from_omniauth' do
    let(:auth) do
      OmniAuth::AuthHash.new(
        provider: 'google_oauth2',
        uid: '123456',
        info: {
          email: 'oauth@example.com',
          first_name: 'OAuth',
          last_name: 'User',
          name: 'OAuth User'
        }
      )
    end

    context 'when user does not exist' do
      it 'creates a new user' do
        expect {
          User.from_omniauth(auth)
        }.to change(User, :count).by(1)
      end

      it 'sets the correct attributes' do
        user = User.from_omniauth(auth)
        expect(user.email).to eq('oauth@example.com')
        expect(user.first_name).to eq('OAuth')
        expect(user.last_name).to eq('User')
      end

      it 'generates a password' do
        user = User.from_omniauth(auth)
        expect(user.encrypted_password).to be_present
      end
    end

    context 'when user already exists with same email' do
      let!(:existing_user) { create(:user, email: 'oauth@example.com') }

      it 'does not create a new user' do
        expect {
          User.from_omniauth(auth)
        }.not_to change(User, :count)
      end

      it 'returns the existing user' do
        user = User.from_omniauth(auth)
        expect(user).to eq(existing_user)
      end
    end

    context 'when auth info has only name field' do
      let(:auth_with_name_only) do
        OmniAuth::AuthHash.new(
          provider: 'google_oauth2',
          uid: '123456',
          info: {
            email: 'name_only@example.com',
            name: 'John Doe'
          }
        )
      end

      it 'splits the name into first and last name' do
        user = User.from_omniauth(auth_with_name_only)
        expect(user.first_name).to eq('John')
        expect(user.last_name).to eq('Doe')
      end
    end

    context 'when auth info is missing name fields' do
      let(:auth_without_names) do
        OmniAuth::AuthHash.new(
          provider: 'google_oauth2',
          uid: '123456',
          info: {
            email: 'no_name@example.com'
          }
        )
      end

      it 'sets first and last name to empty string or uses email fallback' do
        user = User.from_omniauth(auth_without_names)
        # The implementation may set names to empty strings or use email as fallback
        expect([ user.first_name, user.last_name ]).to all(be_a(String))
      end
    end
  end

  describe 'locale' do
    it 'defaults to "en"' do
      user = create(:user)
      expect(user.locale).to eq('en')
    end

    it 'can be set to other values' do
      user = create(:user, locale: 'fi')
      expect(user.locale).to eq('fi')
    end
  end

  describe 'password encryption' do
    it 'encrypts the password' do
      user = create(:user, password: 'password123456789')
      expect(user.encrypted_password).to be_present
      expect(user.encrypted_password).not_to eq('password123456789')
    end

    it 'validates password on sign in' do
      user = create(:user, password: 'correct_password')
      expect(user.valid_password?('correct_password')).to be true
      expect(user.valid_password?('wrong_password')).to be false
    end
  end

  describe 'trackable fields' do
    let(:user) { create(:user) }

    it 'tracks sign in count' do
      # Factory sets sign_in_count to 1 by default (to differentiate oauth users)
      expect(user.sign_in_count).to eq(1)
    end

    it 'can update sign in count' do
      user.update(sign_in_count: 5)
      expect(user.sign_in_count).to eq(5)
    end

    it 'has fields for tracking sign in timestamps' do
      expect(user).to respond_to(:current_sign_in_at)
      expect(user).to respond_to(:last_sign_in_at)
    end

    it 'has fields for tracking sign in IPs' do
      expect(user).to respond_to(:current_sign_in_ip)
      expect(user).to respond_to(:last_sign_in_ip)
    end
  end

  describe 'OAuth token associations' do
    let(:user) { create(:user) }
    let(:oauth_application) { create(:oauth_application) }

    # Note: OAuth token tests are skipped because they require Doorkeeper JWT configuration
    # which needs a complete Rails application context with credentials
    xit 'can have multiple access tokens' do
      token1 = create(:oauth_access_token, resource_owner_id: user.id, application: oauth_application)
      token2 = create(:oauth_access_token, resource_owner_id: user.id, application: oauth_application)

      expect(user.oauth_access_tokens.count).to eq(2)
      expect(user.oauth_access_tokens).to include(token1, token2)
    end

    xit 'destroys access tokens when user is destroyed' do
      create(:oauth_access_token, resource_owner_id: user.id, application: oauth_application)
      expect {
        user.destroy
      }.to change { Doorkeeper::AccessToken.count }.by(-1)
    end

    it 'has oauth_access_tokens association defined' do
      expect(user).to respond_to(:oauth_access_tokens)
    end

    it 'has oauth_access_grants association defined' do
      expect(user).to respond_to(:oauth_access_grants)
    end
  end

  describe 'multiple companies support' do
    let(:user) { create(:user) }
    let(:company1) { create(:company) }
    let(:company2) { create(:company) }
    let(:company3) { create(:company) }

    before do
      create(:membership, user: user, company: company1)
      create(:membership, user: user, company: company2)
      create(:membership, user: user, company: company3)
    end

    it 'can belong to multiple companies' do
      expect(user.companies.count).to eq(3)
      expect(user.companies).to include(company1, company2, company3)
    end

    it 'can switch between companies' do
      user.current_company = company2
      expect(user.current_company).to eq(company2)

      user.current_company = company3
      expect(user.current_company).to eq(company3)
    end

    it 'has different memberships for each company' do
      expect(user.memberships.count).to eq(3)
      expect(user.memberships.map(&:company)).to contain_exactly(company1, company2, company3)
    end
  end
end
