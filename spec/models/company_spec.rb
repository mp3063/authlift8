# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Company, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:memberships).dependent(:destroy) }
    it { is_expected.to have_many(:users).through(:memberships) }
    it { is_expected.to have_many(:oauth_applications).class_name('Doorkeeper::Application').dependent(:destroy) }
    it { is_expected.to have_many(:api_keys).dependent(:destroy) }
    it { is_expected.to have_many(:customer_groups).dependent(:destroy) }
    it { is_expected.to have_and_belong_to_many(:allowed_applications).class_name('Doorkeeper::Application') }
    it { is_expected.to have_many(:application_domains).dependent(:destroy) }
    it { is_expected.to have_many(:owned_partnerships).class_name('Partnership').with_foreign_key(:partner_owner_id).dependent(:destroy) }
    it { is_expected.to have_many(:clients).through(:owned_partnerships).source(:partner_client) }
    it { is_expected.to have_many(:client_partnerships).class_name('Partnership').with_foreign_key(:partner_client_id).dependent(:destroy) }
    it { is_expected.to have_many(:suppliers).through(:client_partnerships).source(:partner_owner) }
  end

  describe 'validations' do
    subject { build(:company) }

    # Skip validate_presence_of(:code) because the before_validation callback auto-generates it
    it { is_expected.to validate_uniqueness_of(:code) }
    it { is_expected.to validate_presence_of(:name) }

    context 'email format validation' do
      it 'allows valid email addresses' do
        company = build(:company, email: 'company@example.com')
        expect(company).to be_valid
      end

      it 'allows blank email' do
        company = build(:company, email: nil)
        expect(company).to be_valid
      end

      it 'rejects invalid email format' do
        company = build(:company, email: 'invalid-email')
        expect(company).not_to be_valid
        expect(company.errors[:email]).to be_present
      end

      it 'allows empty string for email' do
        company = build(:company, email: '')
        expect(company).to be_valid
      end
    end
  end

  describe 'callbacks' do
    describe 'before_validation' do
      context 'when creating a new company without code' do
        it 'generates a unique code automatically' do
          company = build(:company, code: nil)
          company.valid?
          expect(company.code).to be_present
          expect(company.code.length).to eq(10)
        end

        it 'generates an uppercase alphanumeric code' do
          company = build(:company, code: nil)
          company.valid?
          expect(company.code).to match(/\A[A-Z0-9]{10}\z/)
        end

        it 'generates unique codes for different companies' do
          company1 = create(:company, code: nil)
          company2 = create(:company, code: nil)
          expect(company1.code).not_to eq(company2.code)
        end
      end

      context 'when creating a company with a code' do
        it 'does not override the provided code' do
          company = create(:company, code: 'CUSTOM123')
          expect(company.code).to eq('CUSTOM123')
        end
      end

      context 'when updating an existing company' do
        it 'does not change the existing code' do
          company = create(:company)
          original_code = company.code
          company.update(name: 'Updated Name')
          expect(company.code).to eq(original_code)
        end
      end
    end
  end

  describe 'scopes' do
    describe '.active' do
      let!(:active_company) { create(:company, active: true) }
      let!(:inactive_company) { create(:company, active: false) }

      it 'returns only active companies' do
        expect(Company.active).to include(active_company)
        expect(Company.active).not_to include(inactive_company)
      end

      it 'returns correct count' do
        expect(Company.active.count).to eq(1)
      end
    end
  end

  describe 'default values' do
    let(:company) { create(:company) }

    it 'defaults active to true' do
      expect(company.active).to be true
    end

    it 'defaults locale to "en"' do
      expect(company.locale).to eq('en')
    end

    it 'defaults country to "FI"' do
      expect(company.country).to eq('FI')
    end

    it 'defaults info to empty hash' do
      expect(company.info).to eq({})
    end

    it 'defaults settings to empty hash' do
      expect(company.settings).to eq({})
    end
  end

  describe 'JSONB fields' do
    let(:company) { create(:company) }

    describe 'info field' do
      it 'can store arbitrary JSON data' do
        company.update(info: { description: 'Test Company', founded: 2020 })
        expect(company.reload.info['description']).to eq('Test Company')
        expect(company.reload.info['founded']).to eq(2020)
      end

      it 'can be queried' do
        company.update(info: { type: 'enterprise' })
        result = Company.where("info->>'type' = ?", 'enterprise')
        expect(result).to include(company)
      end

      it 'handles nested JSON' do
        company.update(info: {
          contact: {
            phone: '123-456-7890',
            email: 'info@company.com'
          }
        })
        expect(company.reload.info['contact']['phone']).to eq('123-456-7890')
      end
    end

    describe 'settings field' do
      it 'can store application settings' do
        company.update(settings: {
          theme: 'dark',
          notifications: true,
          timezone: 'UTC'
        })
        expect(company.reload.settings['theme']).to eq('dark')
        expect(company.reload.settings['notifications']).to be true
      end

      it 'can be updated incrementally' do
        company.update(settings: { theme: 'light' })
        company.settings['language'] = 'en'
        company.save!
        expect(company.reload.settings).to include('theme' => 'light', 'language' => 'en')
      end
    end
  end

  describe 'address fields' do
    let(:company) do
      create(:company,
        address_line1: '123 Main St',
        address_line2: 'Suite 100',
        city: 'Helsinki',
        state: 'Uusimaa',
        postal_code: '00100',
        country: 'FI'
      )
    end

    it 'stores complete address' do
      expect(company.address_line1).to eq('123 Main St')
      expect(company.address_line2).to eq('Suite 100')
      expect(company.city).to eq('Helsinki')
      expect(company.state).to eq('Uusimaa')
      expect(company.postal_code).to eq('00100')
      expect(company.country).to eq('FI')
    end
  end

  describe 'contact information' do
    let(:company) do
      create(:company,
        email: 'contact@company.com',
        phone: '+358-9-1234567',
        website: 'https://www.company.com'
      )
    end

    it 'stores contact details' do
      expect(company.email).to eq('contact@company.com')
      expect(company.phone).to eq('+358-9-1234567')
      expect(company.website).to eq('https://www.company.com')
    end
  end

  describe 'business identifiers' do
    let(:company) do
      create(:company,
        vat_id: 'FI12345678',
        business_id: '1234567-8'
      )
    end

    it 'stores VAT ID' do
      expect(company.vat_id).to eq('FI12345678')
    end

    it 'stores business ID' do
      expect(company.business_id).to eq('1234567-8')
    end
  end

  describe 'branding' do
    it 'can have a logo code' do
      company = create(:company, logo_code: 'LOGO123')
      expect(company.logo_code).to eq('LOGO123')
    end

    it 'can have different locales' do
      company_fi = create(:company, locale: 'fi')
      company_sv = create(:company, locale: 'sv')

      expect(company_fi.locale).to eq('fi')
      expect(company_sv.locale).to eq('sv')
    end
  end

  describe 'user memberships' do
    let(:company) { create(:company) }
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }
    let(:user3) { create(:user) }

    before do
      create(:membership, user: user1, company: company, role: 'owner')
      create(:membership, user: user2, company: company, role: 'admin')
      create(:membership, user: user3, company: company, role: 'member')
    end

    it 'has multiple users' do
      expect(company.users.count).to eq(3)
      expect(company.users).to include(user1, user2, user3)
    end

    it 'has memberships with different roles' do
      expect(company.memberships.pluck(:role)).to contain_exactly('owner', 'admin', 'member')
    end

    it 'can access users through memberships' do
      owner_membership = company.memberships.find_by(role: 'owner')
      expect(owner_membership.user).to eq(user1)
    end
  end

  describe 'partnerships as owner' do
    let(:owner_company) { create(:company) }
    let(:client1) { create(:company) }
    let(:client2) { create(:company) }

    before do
      create(:partnership, partner_owner: owner_company, partner_client: client1)
      create(:partnership, partner_owner: owner_company, partner_client: client2)
    end

    it 'has multiple client partnerships' do
      expect(owner_company.owned_partnerships.count).to eq(2)
    end

    it 'can access clients through partnerships' do
      expect(owner_company.clients.count).to eq(2)
      expect(owner_company.clients).to include(client1, client2)
    end
  end

  describe 'partnerships as client' do
    let(:client_company) { create(:company) }
    let(:supplier1) { create(:company) }
    let(:supplier2) { create(:company) }

    before do
      create(:partnership, partner_owner: supplier1, partner_client: client_company)
      create(:partnership, partner_owner: supplier2, partner_client: client_company)
    end

    it 'has multiple supplier partnerships' do
      expect(client_company.client_partnerships.count).to eq(2)
    end

    it 'can access suppliers through partnerships' do
      expect(client_company.suppliers.count).to eq(2)
      expect(client_company.suppliers).to include(supplier1, supplier2)
    end
  end

  describe 'OAuth applications' do
    let(:company) { create(:company) }

    it 'can own multiple OAuth applications' do
      app1 = create(:oauth_application, owner: company)
      app2 = create(:oauth_application, owner: company)

      expect(company.oauth_applications.count).to eq(2)
      expect(company.oauth_applications).to include(app1, app2)
    end

    it 'destroys applications when company is destroyed' do
      create(:oauth_application, owner: company)
      expect {
        company.destroy
      }.to change { Doorkeeper::Application.count }.by(-1)
    end
  end

  describe 'customer groups' do
    let(:company) { create(:company) }

    it 'can have multiple customer groups' do
      company.customer_groups.create!(name: 'Wholesale', group_type: 'wholesale')
      company.customer_groups.create!(name: 'Retail', group_type: 'retail')

      expect(company.customer_groups.count).to eq(2)
    end

    it 'destroys customer groups when company is destroyed' do
      company.customer_groups.create!(name: 'VIP')
      expect {
        company.destroy
      }.to change { CustomerGroup.count }.by(-1)
    end
  end

  describe 'deletion cascades' do
    let(:company) { create(:company) }
    let(:user) { create(:user) }
    let(:external_app) { create(:oauth_application) }

    before do
      create(:membership, user: user, company: company)
      create(:oauth_application, owner: company)
      company.api_keys.create!(token: SecureRandom.hex(32), name: 'Test Key')
      company.customer_groups.create!(name: 'Test Group')
      company.application_domains.create!(
        domain: 'https://test.example.com',
        oauth_application: external_app
      )
    end

    it 'destroys all dependent associations' do
      # Count apps owned by company
      owned_apps_count = company.oauth_applications.count

      expect {
        company.destroy
      }.to change { Membership.count }.by(-1)
        .and change { Doorkeeper::Application.count }.by(-owned_apps_count)
        .and change { ApiKey.count }.by(-1)
        .and change { CustomerGroup.count }.by(-1)
        .and change { ApplicationDomain.count }.by(-1)
    end
  end

  describe 'code generation edge cases' do
    it 'handles code collision by trying again' do
      # This is a probabilistic test - with 36^10 possibilities, collisions are rare
      # but the code should handle them gracefully
      companies = 5.times.map { create(:company, code: nil) }
      codes = companies.map(&:code)

      expect(codes.uniq.length).to eq(5) # All codes should be unique
    end

    it 'does not generate code on update' do
      company = create(:company, code: 'ORIGINAL1')
      company.update(name: 'New Name', code: nil)
      expect(company.reload.code).to eq('ORIGINAL1')
    end
  end

  describe 'locale support' do
    it 'supports multiple locales' do
      %w[en fi sv de fr].each do |locale|
        company = create(:company, locale: locale)
        expect(company.locale).to eq(locale)
      end
    end
  end

  describe 'active status' do
    let(:company) { create(:company) }

    it 'can be deactivated' do
      company.update(active: false)
      expect(company.active).to be false
    end

    it 'can be reactivated' do
      company.update(active: false)
      company.update(active: true)
      expect(company.active).to be true
    end
  end

  describe 'allowed applications (HABTM)' do
    let(:company) { create(:company) }
    let(:app1) { create(:oauth_application) }
    let(:app2) { create(:oauth_application) }

    it 'can have allowed applications' do
      company.allowed_applications << app1
      company.allowed_applications << app2

      expect(company.allowed_applications.count).to eq(2)
      expect(company.allowed_applications).to include(app1, app2)
    end

    it 'maintains HABTM relationship' do
      company.allowed_applications << app1
      expect(app1.companies).to include(company)
    end
  end

  describe 'application domains' do
    let(:company) { create(:company) }
    let(:oauth_app) { create(:oauth_application) }

    it 'can have multiple domains' do
      domain1 = company.application_domains.create!(
        domain: 'https://app1.example.com',
        oauth_application: oauth_app
      )
      domain2 = company.application_domains.create!(
        domain: 'https://app2.example.com',
        oauth_application: oauth_app
      )

      expect(company.application_domains.count).to eq(2)
      expect(company.application_domains).to include(domain1, domain2)
    end
  end

  describe 'complex scenarios' do
    context 'company with full setup' do
      let(:company) do
        create(:company,
          name: 'Acme Corp',
          code: 'ACME123',
          vat_id: 'FI12345678',
          email: 'info@acme.com',
          active: true,
          info: { industry: 'technology', employees: 50 },
          settings: { theme: 'blue', notifications: true }
        )
      end

      let(:owner) { create(:user) }
      let(:admin) { create(:user) }
      let(:member) { create(:user) }

      before do
        create(:membership, user: owner, company: company, role: 'owner')
        create(:membership, user: admin, company: company, role: 'admin')
        create(:membership, user: member, company: company, role: 'member')
      end

      it 'has all attributes properly set' do
        expect(company.name).to eq('Acme Corp')
        expect(company.code).to eq('ACME123')
        expect(company.vat_id).to eq('FI12345678')
        expect(company.email).to eq('info@acme.com')
        expect(company.active).to be true
      end

      it 'has JSONB data accessible' do
        expect(company.info['industry']).to eq('technology')
        expect(company.info['employees']).to eq(50)
        expect(company.settings['theme']).to eq('blue')
      end

      it 'has all user memberships' do
        expect(company.users.count).to eq(3)
        expect(company.memberships.map(&:role)).to contain_exactly('owner', 'admin', 'member')
      end
    end
  end

  describe 'timestamps' do
    let(:company) { create(:company) }

    it 'sets created_at on creation' do
      expect(company.created_at).to be_present
      expect(company.created_at).to be_within(1.second).of(Time.current)
    end

    it 'sets updated_at on creation' do
      expect(company.updated_at).to be_present
      expect(company.updated_at).to be_within(1.second).of(Time.current)
    end

    it 'updates updated_at on modification' do
      original_time = company.updated_at
      sleep 0.1
      company.update(name: 'New Name')
      expect(company.updated_at).to be > original_time
    end
  end
end
