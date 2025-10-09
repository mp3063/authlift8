# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Partnership, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:partner_owner).class_name('Company') }
    it { is_expected.to belong_to(:partner_client).class_name('Company') }
    it { is_expected.to have_many(:partnership_apps).dependent(:destroy) }
    it { is_expected.to have_many(:oauth_applications).through(:partnership_apps) }
  end

  describe 'validations' do
    let(:owner_company) { create(:company) }
    let(:client_company) { create(:company) }

    subject { build(:partnership, partner_owner: owner_company, partner_client: client_company) }

    context 'uniqueness validation' do
      before { create(:partnership, partner_owner: owner_company, partner_client: client_company) }

      it 'validates uniqueness of partner_owner_id scoped to partner_client_id' do
        duplicate = build(:partnership, partner_owner: owner_company, partner_client: client_company)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:partner_owner_id]).to be_present
      end

      it 'allows same owner with different clients' do
        other_client = create(:company)
        partnership = build(:partnership, partner_owner: owner_company, partner_client: other_client)
        expect(partnership).to be_valid
      end

      it 'allows different owner with same client' do
        other_owner = create(:company)
        partnership = build(:partnership, partner_owner: other_owner, partner_client: client_company)
        expect(partnership).to be_valid
      end

      it 'allows reverse partnership (client becomes owner, owner becomes client)' do
        reverse_partnership = build(:partnership, partner_owner: client_company, partner_client: owner_company)
        expect(reverse_partnership).to be_valid
      end
    end

    context 'cannot_partner_with_self validation' do
      it 'rejects partnership where owner and client are the same' do
        partnership = build(:partnership, partner_owner: owner_company, partner_client: owner_company)
        expect(partnership).not_to be_valid
        expect(partnership.errors[:partner_client_id]).to include('cannot be the same as owner')
      end

      it 'allows partnership with different companies' do
        partnership = build(:partnership, partner_owner: owner_company, partner_client: client_company)
        expect(partnership).to be_valid
      end
    end
  end

  describe 'scopes' do
    let(:owner) { create(:company) }
    let(:client1) { create(:company) }
    let(:client2) { create(:company) }

    describe '.active' do
      let!(:active_partnership) { create(:partnership, partner_owner: owner, partner_client: client1, active: true) }
      let!(:inactive_partnership) { create(:partnership, partner_owner: owner, partner_client: client2, active: false) }

      it 'returns only active partnerships' do
        expect(Partnership.active).to include(active_partnership)
        expect(Partnership.active).not_to include(inactive_partnership)
      end

      it 'returns correct count' do
        expect(Partnership.active.count).to eq(1)
      end
    end

    describe '.managed' do
      let!(:managed_partnership) do
        create(:partnership, partner_owner: owner, partner_client: client1, managed_company: true)
      end
      let!(:regular_partnership) do
        create(:partnership, partner_owner: owner, partner_client: client2, managed_company: false)
      end

      it 'returns only managed company partnerships' do
        expect(Partnership.managed).to include(managed_partnership)
        expect(Partnership.managed).not_to include(regular_partnership)
      end

      it 'returns correct count' do
        expect(Partnership.managed.count).to eq(1)
      end
    end
  end

  describe 'default values' do
    let(:partnership) { create(:partnership) }

    it 'defaults active to true' do
      expect(partnership.active).to be true
    end

    it 'defaults managed_company to false' do
      expect(partnership.managed_company).to be false
    end

    it 'defaults info to empty hash' do
      expect(partnership.info).to eq({})
    end

    it 'defaults settings to empty hash' do
      expect(partnership.settings).to eq({})
    end
  end

  describe 'JSONB fields' do
    let(:partnership) { create(:partnership) }

    describe 'info field' do
      it 'can store arbitrary metadata' do
        partnership.update(info: {
          established_date: '2025-01-01',
          contract_number: 'CNT-001',
          notes: 'Strategic partner'
        })

        expect(partnership.reload.info['established_date']).to eq('2025-01-01')
        expect(partnership.reload.info['contract_number']).to eq('CNT-001')
        expect(partnership.reload.info['notes']).to eq('Strategic partner')
      end

      it 'handles nested JSON' do
        partnership.update(info: {
          terms: {
            discount_rate: 15,
            payment_terms: 'Net 30'
          }
        })

        expect(partnership.reload.info['terms']['discount_rate']).to eq(15)
        expect(partnership.reload.info['terms']['payment_terms']).to eq('Net 30')
      end

      it 'can be queried' do
        partnership.update(info: { status: 'premium' })
        result = Partnership.where("info->>'status' = ?", 'premium')
        expect(result).to include(partnership)
      end
    end

    describe 'settings field' do
      it 'can store partnership-specific settings' do
        partnership.update(settings: {
          auto_sync: true,
          sync_interval: 'hourly',
          shared_inventory: true
        })

        expect(partnership.reload.settings['auto_sync']).to be true
        expect(partnership.reload.settings['sync_interval']).to eq('hourly')
        expect(partnership.reload.settings['shared_inventory']).to be true
      end

      it 'can be updated incrementally' do
        partnership.update(settings: { feature_a: true })
        partnership.settings['feature_b'] = false
        partnership.save!

        expect(partnership.reload.settings).to include('feature_a' => true, 'feature_b' => false)
      end
    end
  end

  describe 'partnership relationships' do
    let(:supplier) { create(:company, name: 'Supplier Inc') }
    let(:customer) { create(:company, name: 'Customer Corp') }
    let!(:partnership) { create(:partnership, partner_owner: supplier, partner_client: customer) }

    it 'correctly identifies owner company' do
      expect(partnership.partner_owner).to eq(supplier)
    end

    it 'correctly identifies client company' do
      expect(partnership.partner_client).to eq(customer)
    end

    it 'is accessible from owner company' do
      expect(supplier.owned_partnerships).to include(partnership)
    end

    it 'is accessible from client company' do
      expect(customer.client_partnerships).to include(partnership)
    end

    it 'owner can access clients through partnerships' do
      expect(supplier.clients).to include(customer)
    end

    it 'client can access suppliers through partnerships' do
      expect(customer.suppliers).to include(supplier)
    end
  end

  describe 'partnership apps' do
    let(:partnership) { create(:partnership) }
    let(:oauth_app) { create(:oauth_application) }

    it 'can have associated OAuth applications' do
      partnership.partnership_apps.create!(oauth_application: oauth_app, active: true)
      expect(partnership.oauth_applications).to include(oauth_app)
    end

    it 'can have multiple applications' do
      app1 = create(:oauth_application)
      app2 = create(:oauth_application)

      partnership.partnership_apps.create!(oauth_application: app1, active: true)
      partnership.partnership_apps.create!(oauth_application: app2, active: true)

      expect(partnership.oauth_applications.count).to eq(2)
      expect(partnership.oauth_applications).to include(app1, app2)
    end

    it 'destroys partnership_apps when partnership is destroyed' do
      partnership.partnership_apps.create!(oauth_application: oauth_app, active: true)

      expect {
        partnership.destroy
      }.to change { PartnershipApp.count }.by(-1)
    end
  end

  describe 'managed company partnerships' do
    let(:parent_company) { create(:company, name: 'Parent Corp') }
    let(:subsidiary) { create(:company, name: 'Subsidiary LLC') }

    context 'when managed_company is true' do
      let(:managed_partnership) do
        create(:partnership,
          partner_owner: parent_company,
          partner_client: subsidiary,
          managed_company: true
        )
      end

      it 'indicates a managed relationship' do
        expect(managed_partnership.managed_company).to be true
      end

      it 'is included in managed scope' do
        expect(Partnership.managed).to include(managed_partnership)
      end
    end

    context 'when managed_company is false' do
      let(:regular_partnership) do
        create(:partnership,
          partner_owner: parent_company,
          partner_client: subsidiary,
          managed_company: false
        )
      end

      it 'indicates a regular partnership' do
        expect(regular_partnership.managed_company).to be false
      end

      it 'is not included in managed scope' do
        expect(Partnership.managed).not_to include(regular_partnership)
      end
    end
  end

  describe 'complex scenarios' do
    context 'supply chain with multiple tiers' do
      let(:manufacturer) { create(:company, name: 'Manufacturer') }
      let(:distributor) { create(:company, name: 'Distributor') }
      let(:retailer) { create(:company, name: 'Retailer') }

      before do
        create(:partnership, partner_owner: manufacturer, partner_client: distributor)
        create(:partnership, partner_owner: distributor, partner_client: retailer)
      end

      it 'manufacturer has distributor as client' do
        expect(manufacturer.clients).to include(distributor)
      end

      it 'distributor has manufacturer as supplier' do
        expect(distributor.suppliers).to include(manufacturer)
      end

      it 'distributor has retailer as client' do
        expect(distributor.clients).to include(retailer)
      end

      it 'retailer has distributor as supplier' do
        expect(retailer.suppliers).to include(distributor)
      end

      it 'maintains separate partnership records' do
        expect(manufacturer.owned_partnerships.count).to eq(1)
        expect(distributor.owned_partnerships.count).to eq(1)
        expect(distributor.client_partnerships.count).to eq(1)
      end
    end

    context 'company with multiple suppliers and clients' do
      let(:company) { create(:company, name: 'Central Company') }
      let(:supplier1) { create(:company, name: 'Supplier 1') }
      let(:supplier2) { create(:company, name: 'Supplier 2') }
      let(:client1) { create(:company, name: 'Client 1') }
      let(:client2) { create(:company, name: 'Client 2') }
      let(:client3) { create(:company, name: 'Client 3') }

      before do
        # As client (buying from suppliers)
        create(:partnership, partner_owner: supplier1, partner_client: company)
        create(:partnership, partner_owner: supplier2, partner_client: company)

        # As owner (selling to clients)
        create(:partnership, partner_owner: company, partner_client: client1)
        create(:partnership, partner_owner: company, partner_client: client2)
        create(:partnership, partner_owner: company, partner_client: client3)
      end

      it 'has correct number of supplier relationships' do
        expect(company.suppliers.count).to eq(2)
      end

      it 'has correct number of client relationships' do
        expect(company.clients.count).to eq(3)
      end

      it 'can identify all suppliers' do
        expect(company.suppliers).to include(supplier1, supplier2)
      end

      it 'can identify all clients' do
        expect(company.clients).to include(client1, client2, client3)
      end

      it 'has correct total partnerships' do
        total_partnerships = company.owned_partnerships.count + company.client_partnerships.count
        expect(total_partnerships).to eq(5)
      end
    end

    context 'bidirectional partnerships' do
      let(:company_a) { create(:company, name: 'Company A') }
      let(:company_b) { create(:company, name: 'Company B') }

      before do
        create(:partnership, partner_owner: company_a, partner_client: company_b)
        create(:partnership, partner_owner: company_b, partner_client: company_a)
      end

      it 'allows partnerships in both directions' do
        expect(company_a.clients).to include(company_b)
        expect(company_a.suppliers).to include(company_b)
      end

      it 'maintains separate partnership records' do
        expect(Partnership.where(partner_owner: company_a, partner_client: company_b).count).to eq(1)
        expect(Partnership.where(partner_owner: company_b, partner_client: company_a).count).to eq(1)
      end
    end
  end

  describe 'active status management' do
    let(:partnership) { create(:partnership) }

    it 'can be deactivated' do
      partnership.update(active: false)
      expect(partnership.active).to be false
    end

    it 'can be reactivated' do
      partnership.update(active: false)
      partnership.update(active: true)
      expect(partnership.active).to be true
    end

    it 'inactive partnerships are excluded from active scope' do
      active_partnership = create(:partnership, active: true)
      inactive_partnership = create(:partnership, active: false)

      expect(Partnership.active).to include(active_partnership)
      expect(Partnership.active).not_to include(inactive_partnership)
    end
  end

  describe 'deletion cascades' do
    let(:partnership) { create(:partnership) }
    let(:oauth_app) { create(:oauth_application) }

    before do
      partnership.partnership_apps.create!(oauth_application: oauth_app, active: true)
    end

    it 'destroys partnership_apps when destroyed' do
      expect {
        partnership.destroy
      }.to change { PartnershipApp.count }.by(-1)
    end

    it 'does not destroy associated companies' do
      owner_id = partnership.partner_owner_id
      client_id = partnership.partner_client_id

      partnership.destroy

      expect(Company.find_by(id: owner_id)).to be_present
      expect(Company.find_by(id: client_id)).to be_present
    end

    it 'does not destroy associated OAuth applications' do
      app_id = oauth_app.id
      partnership.destroy

      expect(Doorkeeper::Application.find_by(id: app_id)).to be_present
    end
  end

  describe 'timestamps' do
    let(:partnership) { create(:partnership) }

    it 'sets created_at on creation' do
      expect(partnership.created_at).to be_present
      expect(partnership.created_at).to be_within(1.second).of(Time.current)
    end

    it 'sets updated_at on creation' do
      expect(partnership.updated_at).to be_present
      expect(partnership.updated_at).to be_within(1.second).of(Time.current)
    end

    it 'updates updated_at on modification' do
      original_time = partnership.updated_at
      sleep 0.1
      partnership.update(active: false)
      expect(partnership.updated_at).to be > original_time
    end
  end

  describe 'factory default' do
    it 'creates a valid partnership with different companies' do
      owner = create(:company)
      client = create(:company)
      partnership = build(:partnership, partner_owner: owner, partner_client: client)
      expect(partnership).to be_valid
      expect(partnership.partner_owner_id).not_to eq(partnership.partner_client_id)
    end
  end

  describe 'edge cases' do
    context 'when trying to create duplicate partnership' do
      let(:owner) { create(:company) }
      let(:client) { create(:company) }

      before { create(:partnership, partner_owner: owner, partner_client: client) }

      it 'prevents duplicate partnerships' do
        duplicate = build(:partnership, partner_owner: owner, partner_client: client)
        expect(duplicate).not_to be_valid
      end

      it 'shows appropriate error message' do
        duplicate = build(:partnership, partner_owner: owner, partner_client: client)
        duplicate.valid?
        expect(duplicate.errors[:partner_owner_id]).to be_present
      end
    end

    context 'when trying to partner with self' do
      let(:company) { create(:company) }

      it 'prevents self-partnership' do
        partnership = build(:partnership, partner_owner: company, partner_client: company)
        expect(partnership).not_to be_valid
      end

      it 'shows appropriate error message' do
        partnership = build(:partnership, partner_owner: company, partner_client: company)
        partnership.valid?
        expect(partnership.errors[:partner_client_id]).to include('cannot be the same as owner')
      end
    end

    context 'when deleting owner company' do
      let(:partnership) { create(:partnership) }

      it 'destroys the partnership' do
        owner = partnership.partner_owner
        expect {
          owner.destroy
        }.to change { Partnership.count }.by(-1)
      end
    end

    context 'when deleting client company' do
      let(:partnership) { create(:partnership) }

      it 'destroys the partnership' do
        client = partnership.partner_client
        expect {
          client.destroy
        }.to change { Partnership.count }.by(-1)
      end
    end
  end

  describe 'querying partnerships' do
    let(:company_a) { create(:company) }
    let(:company_b) { create(:company) }
    let(:company_c) { create(:company) }

    before do
      create(:partnership, partner_owner: company_a, partner_client: company_b, active: true)
      create(:partnership, partner_owner: company_a, partner_client: company_c, active: false)
      create(:partnership, partner_owner: company_b, partner_client: company_c, managed_company: true)
    end

    it 'can find partnerships by owner' do
      partnerships = Partnership.where(partner_owner: company_a)
      expect(partnerships.count).to eq(2)
    end

    it 'can find partnerships by client' do
      partnerships = Partnership.where(partner_client: company_c)
      expect(partnerships.count).to eq(2)
    end

    it 'can find active partnerships by owner' do
      partnerships = Partnership.where(partner_owner: company_a).active
      expect(partnerships.count).to eq(1)
    end

    it 'can find managed partnerships' do
      partnerships = Partnership.managed
      expect(partnerships.count).to eq(1)
      expect(partnerships.first.partner_owner).to eq(company_b)
    end
  end
end
