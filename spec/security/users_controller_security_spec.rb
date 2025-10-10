# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::UsersController Security', type: :request do
  # Setup test data
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  let(:company1) { create(:company, code: 'COMP001', name: 'Active Company') }
  let(:company2) { create(:company, code: 'COMP002', name: 'Inactive Company') }
  let(:company3) { create(:company, code: 'COMP003', name: 'Other User Company') }

  let(:active_membership1) do
    create(:membership, :admin, user: user, company: company1, active: true, scopes: [ 'products:read' ])
  end

  let(:inactive_membership) do
    create(:membership, user: user, company: company2, active: false, scopes: [ 'products:read' ])
  end

  let(:other_user_membership) do
    create(:membership, :owner, user: other_user, company: company3, active: true)
  end

  # OAuth access token for authentication
  let(:oauth_application) { create(:oauth_application) }
  let(:access_token) do
    create(:oauth_access_token,
           resource_owner_id: user.id,
           application_id: oauth_application.id,
           scopes: 'public')
  end

  # Helper to make authenticated requests
  def authenticated_get(path, params = {})
    get path, params: params, headers: { 'Authorization' => "Bearer #{access_token.token}" }
  end

  before do
    # Setup user with active and inactive memberships
    active_membership1
    inactive_membership
    other_user_membership
    user.update(company: company1)
  end

  describe 'IDOR Protection in company_info endpoint' do
    context 'GET /api/v1/users/company_info/:company_id' do
      it 'allows access to company with active membership' do
        authenticated_get "/api/v1/users/company_info/#{company1.id}"

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['company']['id']).to eq(company1.id)
        expect(json['company']['name']).to eq('Active Company')
        expect(json['membership']['active']).to be true
      end

      it 'blocks access to company with inactive membership (IDOR protection)' do
        expect(Rails.logger).to receive(:warn).with(
          /SECURITY: User #{user.id} attempted to access company #{company2.id} with inactive membership/
        )

        authenticated_get "/api/v1/users/company_info/#{company2.id}"

        expect(response).to have_http_status(:forbidden)

        json = JSON.parse(response.body)
        expect(json['error']).to eq('Access denied - membership inactive')
      end

      it 'blocks access to company without any membership (IDOR protection)' do
        expect(Rails.logger).to receive(:warn).with(
          /SECURITY: User #{user.id} attempted to access company #{company3.id} without active membership - IP:/
        )

        authenticated_get "/api/v1/users/company_info/#{company3.id}"

        expect(response).to have_http_status(:forbidden)

        json = JSON.parse(response.body)
        expect(json['error']).to eq('Company not found or access denied')
      end

      it 'blocks access to non-existent company' do
        non_existent_id = 99999

        expect(Rails.logger).to receive(:warn).with(
          /SECURITY: User #{user.id} attempted to access company #{non_existent_id} without active membership/
        )

        authenticated_get "/api/v1/users/company_info/#{non_existent_id}"

        expect(response).to have_http_status(:forbidden)

        json = JSON.parse(response.body)
        expect(json['error']).to eq('Company not found or access denied')
      end

      it 'logs security-relevant access attempts with IP address' do
        expect(Rails.logger).to receive(:warn).with(
          /SECURITY: User #{user.id} attempted to access company #{company3.id} without active membership - IP:/
        )

        authenticated_get "/api/v1/users/company_info/#{company3.id}"
      end

      it 'returns current company when no company_id is provided' do
        authenticated_get '/api/v1/users/company_info'

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['company']['id']).to eq(company1.id)
      end

      it 'includes partnership information for authorized company' do
        # Create some partnerships
        supplier = create(:company)
        client = create(:company)

        company1.owned_partnerships.create!(
          partner_client: client,
          active: true,
          info: {}
        )

        company1.client_partnerships.create!(
          partner_owner: supplier,
          active: true,
          info: {}
        )

        authenticated_get "/api/v1/users/company_info/#{company1.id}"

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['partnerships']['as_owner']).to eq(1)
        expect(json['partnerships']['as_client']).to eq(1)
      end

      it 'does not leak partnership data for unauthorized company' do
        # Attempt to access company2 (inactive membership)
        authenticated_get "/api/v1/users/company_info/#{company2.id}"

        expect(response).to have_http_status(:forbidden)

        # Verify no partnership data is returned
        json = JSON.parse(response.body)
        expect(json['partnerships']).to be_nil
        expect(json['suppliers']).to be_nil
        expect(json['clients']).to be_nil
      end
    end
  end

  describe 'Profile endpoint - Active Membership Filter' do
    context 'GET /api/v1/users/profile' do
      it 'returns user profile successfully' do
        authenticated_get '/api/v1/users/profile'

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['id']).to eq(user.id)
        expect(json['email']).to eq(user.email)
        expect(json['first_name']).to eq(user.first_name)
        expect(json['last_name']).to eq(user.last_name)
      end

      it 'only includes companies with active memberships in all_companies' do
        authenticated_get '/api/v1/users/profile'

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        company_ids = json['all_companies'].map { |c| c['id'] }

        # Should include company1 (active membership)
        expect(company_ids).to include(company1.id)

        # Should NOT include company2 (inactive membership)
        expect(company_ids).not_to include(company2.id)

        # Verify only active companies are returned
        expect(json['all_companies'].count).to eq(1)
      end

      it 'returns current company from active membership' do
        authenticated_get '/api/v1/users/profile'

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['company']['id']).to eq(company1.id)
        expect(json['company']['code']).to eq('COMP001')
      end

      it 'returns current membership data from active membership' do
        authenticated_get '/api/v1/users/profile'

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['membership']['id']).to eq(active_membership1.id)
        expect(json['membership']['role']).to eq('admin')
        expect(json['membership']['active']).to be true
        expect(json['membership']['scopes']).to eq([ 'products:read' ])
      end

      it 'includes complete user profile data' do
        authenticated_get '/api/v1/users/profile'

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)

        # User data
        expect(json['email']).to eq(user.email)
        expect(json['first_name']).to eq(user.first_name)
        expect(json['last_name']).to eq(user.last_name)
        expect(json['full_name']).to eq("#{user.first_name} #{user.last_name}")
        expect(json['locale']).to eq(user.locale)

        # Company data structure
        expect(json['company']).to include('id', 'code', 'name', 'email', 'address')

        # Membership data
        expect(json['membership']).to include('id', 'role', 'scopes', 'active')
      end

      it 'handles user with no active memberships gracefully' do
        # Deactivate all memberships
        user.memberships.update_all(active: false)

        authenticated_get '/api/v1/users/profile'

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['company']).to be_nil
        expect(json['membership']).to be_nil
        expect(json['all_companies']).to be_empty
      end

      it 'requires authentication' do
        get '/api/v1/users/profile'

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns 404 when user is deleted but token still exists' do
        # Simulate scenario where token exists but user is deleted
        user_id = user.id
        user.destroy

        # Create orphaned token
        orphaned_token = create(:oauth_access_token,
                                resource_owner_id: user_id,
                                application_id: oauth_application.id)

        get '/api/v1/users/profile',
            headers: { 'Authorization' => "Bearer #{orphaned_token.token}" }

        expect(response).to have_http_status(:not_found)

        json = JSON.parse(response.body)
        expect(json['error']).to eq('User not found')
      end
    end
  end

  describe 'Multiple Active Memberships Scenario' do
    let(:company4) { create(:company, code: 'COMP004', name: 'Second Active Company') }
    let(:active_membership2) do
      create(:membership, :owner, user: user, company: company4, active: true)
    end

    before do
      active_membership2
    end

    it 'includes all companies with active memberships in profile' do
      authenticated_get '/api/v1/users/profile'

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      company_ids = json['all_companies'].map { |c| c['id'] }

      expect(company_ids).to include(company1.id, company4.id)
      expect(company_ids).not_to include(company2.id) # inactive
      expect(json['all_companies'].count).to eq(2)
    end

    it 'allows access to any company with active membership' do
      # Access first company
      authenticated_get "/api/v1/users/company_info/#{company1.id}"
      expect(response).to have_http_status(:ok)

      # Access second company
      authenticated_get "/api/v1/users/company_info/#{company4.id}"
      expect(response).to have_http_status(:ok)

      # Still blocked from inactive membership
      authenticated_get "/api/v1/users/company_info/#{company2.id}"
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'Security - Data Isolation' do
    it 'does not expose other users\' companies in profile' do
      authenticated_get '/api/v1/users/profile'

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      company_ids = json['all_companies'].map { |c| c['id'] }

      # Should NOT include other_user's company
      expect(company_ids).not_to include(company3.id)
    end

    it 'prevents horizontal privilege escalation via company_id parameter' do
      # Attempt to access another user's company
      expect(Rails.logger).to receive(:warn).with(
        /SECURITY: User #{user.id} attempted to access company #{company3.id} without active membership/
      )

      authenticated_get "/api/v1/users/company_info/#{company3.id}"

      expect(response).to have_http_status(:forbidden)
    end

    it 'includes proper address data structure without exposing internal fields' do
      authenticated_get "/api/v1/users/company_info/#{company1.id}"

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      address = json['company']['address']

      # Verify address structure
      expect(address).to include('line1', 'line2', 'city', 'state', 'postal_code', 'country')

      # Verify no internal Rails fields are exposed
      expect(json['company']).not_to include('created_at', 'updated_at')
    end
  end

  describe 'Error Handling and Edge Cases' do
    it 'handles internal server errors gracefully in profile endpoint' do
      allow_any_instance_of(Api::V1::UsersController).to receive(:user_profile_response)
        .and_raise(StandardError.new('Database error'))

      expect(Rails.logger).to receive(:error).with(/Profile fetch error: Database error/)

      authenticated_get '/api/v1/users/profile'

      expect(response).to have_http_status(:internal_server_error)

      json = JSON.parse(response.body)
      expect(json['error']).to eq('Unable to fetch profile')
    end

    it 'handles internal server errors gracefully in company_info endpoint' do
      allow_any_instance_of(Api::V1::UsersController).to receive(:company_info_response)
        .and_raise(StandardError.new('Database error'))

      expect(Rails.logger).to receive(:error).with(/Company info fetch error: Database error/)

      authenticated_get "/api/v1/users/company_info/#{company1.id}"

      expect(response).to have_http_status(:internal_server_error)

      json = JSON.parse(response.body)
      expect(json['error']).to eq('Unable to fetch company information')
    end

    it 'handles company without memberships' do
      # Create a company but no membership for current user
      orphan_company = create(:company)

      expect(Rails.logger).to receive(:warn).with(
        /SECURITY: User #{user.id} attempted to access company #{orphan_company.id} without active membership/
      )

      authenticated_get "/api/v1/users/company_info/#{orphan_company.id}"

      expect(response).to have_http_status(:forbidden)
    end

    it 'handles nil company gracefully' do
      # User with no current company set
      user.update(company: nil)

      authenticated_get '/api/v1/users/company_info'

      # Should use first active membership's company
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['company']['id']).to eq(company1.id)
    end
  end

  describe 'Response Data Validation' do
    it 'returns complete company data structure' do
      authenticated_get "/api/v1/users/company_info/#{company1.id}"

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      company = json['company']

      expect(company).to include(
        'id', 'code', 'name', 'logo_code', 'vat_id', 'business_id',
        'email', 'phone', 'website', 'locale', 'active', 'info', 'address'
      )
    end

    it 'returns complete membership data structure' do
      authenticated_get "/api/v1/users/company_info/#{company1.id}"

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      membership = json['membership']

      expect(membership).to include(
        'id', 'role', 'scopes', 'active', 'info', 'created_at', 'updated_at'
      )
    end

    it 'returns suppliers and clients arrays' do
      authenticated_get "/api/v1/users/company_info/#{company1.id}"

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)

      expect(json['suppliers']).to be_an(Array)
      expect(json['clients']).to be_an(Array)
      expect(json['partnerships']).to include('as_owner', 'as_client')
    end
  end

  describe 'Access Control - Membership Status Transitions' do
    it 'grants access when membership becomes active' do
      # Initially inactive
      expect(inactive_membership.active).to be false

      authenticated_get "/api/v1/users/company_info/#{company2.id}"
      expect(response).to have_http_status(:forbidden)

      # Activate membership
      inactive_membership.update(active: true)

      # Now should have access
      authenticated_get "/api/v1/users/company_info/#{company2.id}"
      expect(response).to have_http_status(:ok)
    end

    it 'revokes access when membership becomes inactive' do
      # Initially active
      expect(active_membership1.active).to be true

      authenticated_get "/api/v1/users/company_info/#{company1.id}"
      expect(response).to have_http_status(:ok)

      # Deactivate membership
      active_membership1.update(active: false)

      expect(Rails.logger).to receive(:warn).with(
        /SECURITY: User #{user.id} attempted to access company #{company1.id} with inactive membership/
      )

      # Now should be denied
      authenticated_get "/api/v1/users/company_info/#{company1.id}"
      expect(response).to have_http_status(:forbidden)
    end
  end
end
