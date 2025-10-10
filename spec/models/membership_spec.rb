# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Membership, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:company) }
  end

  describe 'validations' do
    subject { build(:membership) }

    it { is_expected.to validate_presence_of(:role) }
    it { is_expected.to validate_inclusion_of(:role).in_array(%w[owner admin member]) }

    context 'uniqueness validation' do
      let(:user) { create(:user) }
      let(:company) { create(:company) }

      before { create(:membership, user: user, company: company) }

      it 'validates uniqueness of user_id scoped to company_id' do
        duplicate = build(:membership, user: user, company: company)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:user_id]).to be_present
      end

      it 'allows same user in different companies' do
        other_company = create(:company)
        membership = build(:membership, user: user, company: other_company)
        expect(membership).to be_valid
      end

      it 'allows different users in same company' do
        other_user = create(:user)
        membership = build(:membership, user: other_user, company: company)
        expect(membership).to be_valid
      end
    end

    context 'role validation' do
      let(:membership) { build(:membership) }

      it 'accepts "owner" as a valid role' do
        membership.role = 'owner'
        expect(membership).to be_valid
      end

      it 'accepts "admin" as a valid role' do
        membership.role = 'admin'
        expect(membership).to be_valid
      end

      it 'accepts "member" as a valid role' do
        membership.role = 'member'
        expect(membership).to be_valid
      end

      it 'rejects invalid roles' do
        membership.role = 'superuser'
        expect(membership).not_to be_valid
        expect(membership.errors[:role]).to be_present
      end

      it 'rejects nil role' do
        membership.role = nil
        expect(membership).not_to be_valid
        expect(membership.errors[:role]).to be_present
      end
    end
  end

  describe 'scopes' do
    let(:company) { create(:company) }

    describe '.active' do
      let!(:active_membership) { create(:membership, company: company, active: true) }
      let!(:inactive_membership) { create(:membership, company: company, active: false) }

      it 'returns only active memberships' do
        expect(Membership.active).to include(active_membership)
        expect(Membership.active).not_to include(inactive_membership)
      end
    end

    describe '.owners' do
      let!(:owner_membership) { create(:membership, company: company, role: 'owner') }
      let!(:admin_membership) { create(:membership, company: company, role: 'admin') }
      let!(:member_membership) { create(:membership, company: company, role: 'member') }

      it 'returns only owner memberships' do
        expect(Membership.owners).to include(owner_membership)
        expect(Membership.owners).not_to include(admin_membership, member_membership)
      end
    end

    describe '.admins' do
      let!(:owner_membership) { create(:membership, company: company, role: 'owner') }
      let!(:admin_membership) { create(:membership, company: company, role: 'admin') }
      let!(:member_membership) { create(:membership, company: company, role: 'member') }

      it 'returns only admin memberships' do
        expect(Membership.admins).to include(admin_membership)
        expect(Membership.admins).not_to include(owner_membership, member_membership)
      end
    end
  end

  describe 'role checking methods' do
    describe '#owner?' do
      it 'returns true when role is owner' do
        membership = build(:membership, role: 'owner')
        expect(membership.owner?).to be true
      end

      it 'returns false when role is admin' do
        membership = build(:membership, role: 'admin')
        expect(membership.owner?).to be false
      end

      it 'returns false when role is member' do
        membership = build(:membership, role: 'member')
        expect(membership.owner?).to be false
      end
    end

    describe '#admin?' do
      it 'returns true when role is admin' do
        membership = build(:membership, role: 'admin')
        expect(membership.admin?).to be true
      end

      it 'returns false when role is owner' do
        membership = build(:membership, role: 'owner')
        expect(membership.admin?).to be false
      end

      it 'returns false when role is member' do
        membership = build(:membership, role: 'member')
        expect(membership.admin?).to be false
      end
    end

    describe '#member?' do
      it 'returns true when role is member' do
        membership = build(:membership, role: 'member')
        expect(membership.member?).to be true
      end

      it 'returns false when role is owner' do
        membership = build(:membership, role: 'owner')
        expect(membership.member?).to be false
      end

      it 'returns false when role is admin' do
        membership = build(:membership, role: 'admin')
        expect(membership.member?).to be false
      end
    end
  end

  describe 'scope management methods' do
    let(:membership) { create(:membership, scopes: [ 'products:read' ]) }

    describe '#add_scope' do
      it 'adds a new scope to the membership' do
        expect {
          membership.add_scope('products:write')
        }.to change { membership.reload.scopes }.from([ 'products:read' ]).to([ 'products:read', 'products:write' ])
      end

      it 'does not add duplicate scopes' do
        membership.add_scope('products:read')
        expect(membership.reload.scopes).to eq([ 'products:read' ])
      end

      it 'handles symbol input' do
        membership.add_scope(:'orders:read')
        expect(membership.reload.scopes).to include('orders:read')
      end

      it 'handles string input' do
        membership.add_scope('orders:read')
        expect(membership.reload.scopes).to include('orders:read')
      end

      context 'when scopes is initially empty' do
        let(:membership) { create(:membership, scopes: []) }

        it 'adds the first scope' do
          membership.add_scope('products:read')
          expect(membership.reload.scopes).to eq([ 'products:read' ])
        end
      end

      context 'when scopes is nil' do
        let(:membership) { create(:membership, scopes: nil) }

        it 'initializes scopes and adds the scope' do
          membership.add_scope('products:read')
          expect(membership.reload.scopes).to eq([ 'products:read' ])
        end
      end
    end

    describe '#remove_scope' do
      let(:membership) { create(:membership, scopes: [ 'products:read', 'products:write', 'orders:read' ]) }

      it 'removes an existing scope' do
        expect {
          membership.remove_scope('products:write')
        }.to change { membership.reload.scopes }.from([ 'products:read', 'products:write', 'orders:read' ]).to([ 'products:read', 'orders:read' ])
      end

      it 'does nothing if scope does not exist' do
        original_scopes = membership.scopes.dup
        membership.remove_scope('users:read')
        expect(membership.reload.scopes).to eq(original_scopes)
      end

      it 'handles symbol input' do
        membership.remove_scope(:'products:read')
        expect(membership.reload.scopes).not_to include('products:read')
      end

      it 'handles string input' do
        membership.remove_scope('products:read')
        expect(membership.reload.scopes).not_to include('products:read')
      end

      context 'when scopes is empty' do
        let(:membership) { create(:membership, scopes: []) }

        it 'does not raise an error' do
          expect {
            membership.remove_scope('products:read')
          }.not_to raise_error
        end
      end

      context 'when scopes is nil' do
        let(:membership) { create(:membership, scopes: nil) }

        it 'does not raise an error' do
          expect {
            membership.remove_scope('products:read')
          }.not_to raise_error
        end
      end
    end

    describe '#has_scope?' do
      let(:membership) { create(:membership, role: 'member', scopes: [ 'products:read', 'products:write' ]) }

      context 'for member role' do
        it 'returns true for scopes the membership has' do
          expect(membership.has_scope?('products:read')).to be true
          expect(membership.has_scope?('products:write')).to be true
        end

        it 'returns false for scopes the membership lacks' do
          expect(membership.has_scope?('products:delete')).to be false
          expect(membership.has_scope?('users:read')).to be false
        end

        it 'handles scope as a symbol' do
          expect(membership.has_scope?(:'products:read')).to be true
        end

        it 'handles scope as a string' do
          expect(membership.has_scope?('products:read')).to be true
        end
      end

      context 'for owner role' do
        let(:owner_membership) { create(:membership, role: 'owner', scopes: []) }

        it 'returns true for any scope' do
          expect(owner_membership.has_scope?('anything')).to be true
          expect(owner_membership.has_scope?('products:delete')).to be true
          expect(owner_membership.has_scope?('users:admin')).to be true
        end

        it 'returns true even with empty scopes array' do
          expect(owner_membership.scopes).to eq([])
          expect(owner_membership.has_scope?('any:scope')).to be true
        end
      end

      context 'for admin role' do
        let(:admin_membership) { create(:membership, role: 'admin', scopes: []) }

        it 'returns true for any scope' do
          expect(admin_membership.has_scope?('anything')).to be true
          expect(admin_membership.has_scope?('products:delete')).to be true
          expect(admin_membership.has_scope?('users:admin')).to be true
        end
      end

      context 'when scopes is empty' do
        let(:membership) { create(:membership, role: 'member', scopes: []) }

        it 'returns false for any scope' do
          expect(membership.has_scope?('products:read')).to be false
        end
      end

      context 'when scopes is nil' do
        let(:membership) { create(:membership, role: 'member', scopes: nil) }

        it 'returns false for any scope' do
          expect(membership.has_scope?('products:read')).to be false
        end
      end
    end
  end

  describe 'default values' do
    let(:membership) { create(:membership) }

    it 'defaults role to "member"' do
      expect(membership.role).to eq('member')
    end

    it 'defaults scopes to empty array' do
      expect(membership.scopes).to eq([])
    end

    it 'defaults active to true' do
      expect(membership.active).to be true
    end

    it 'defaults info to empty hash' do
      expect(membership.info).to eq({})
    end
  end

  describe 'JSONB fields' do
    let(:membership) { create(:membership) }

    describe 'scopes field' do
      it 'stores array of scopes' do
        membership.update(scopes: [ 'products:read', 'products:write', 'orders:read' ])
        expect(membership.reload.scopes).to eq([ 'products:read', 'products:write', 'orders:read' ])
      end

      it 'can be queried' do
        membership.update(scopes: [ 'admin:access' ])
        result = Membership.where("scopes ? 'admin:access'")
        expect(result).to include(membership)
      end

      it 'handles empty array' do
        membership.update(scopes: [])
        expect(membership.reload.scopes).to eq([])
      end
    end

    describe 'info field' do
      it 'can store arbitrary metadata' do
        membership.update(info: {
          joined_at: '2025-01-01',
          invited_by: 'user@example.com',
          department: 'Engineering'
        })

        expect(membership.reload.info['joined_at']).to eq('2025-01-01')
        expect(membership.reload.info['invited_by']).to eq('user@example.com')
        expect(membership.reload.info['department']).to eq('Engineering')
      end

      it 'handles nested JSON' do
        membership.update(info: {
          preferences: {
            language: 'en',
            notifications: true
          }
        })

        expect(membership.reload.info['preferences']['language']).to eq('en')
      end
    end
  end

  describe 'factory traits' do
    describe ':owner trait' do
      let(:membership) { build(:membership, :owner) }

      it 'sets role to owner' do
        expect(membership.role).to eq('owner')
      end
    end

    describe ':admin trait' do
      let(:membership) { build(:membership, :admin) }

      it 'sets role to admin' do
        expect(membership.role).to eq('admin')
      end
    end

    describe ':with_scopes trait' do
      let(:membership) { build(:membership, :with_scopes) }

      it 'includes predefined scopes' do
        expect(membership.scopes).to include('products:read', 'products:write')
      end
    end
  end

  describe 'complex scenarios' do
    context 'user with multiple company memberships' do
      let(:user) { create(:user) }
      let(:company1) { create(:company) }
      let(:company2) { create(:company) }
      let(:company3) { create(:company) }

      before do
        create(:membership, user: user, company: company1, role: 'owner')
        create(:membership, user: user, company: company2, role: 'admin')
        create(:membership, user: user, company: company3, role: 'member')
      end

      it 'has different roles in different companies' do
        expect(user.memberships.count).to eq(3)
        expect(user.memberships.find_by(company: company1).role).to eq('owner')
        expect(user.memberships.find_by(company: company2).role).to eq('admin')
        expect(user.memberships.find_by(company: company3).role).to eq('member')
      end

      it 'has different scopes per company' do
        user.memberships.find_by(company: company1).update(scopes: [ 'all:access' ])
        user.memberships.find_by(company: company2).update(scopes: [ 'products:read', 'orders:read' ])
        user.memberships.find_by(company: company3).update(scopes: [ 'products:read' ])

        expect(user.memberships.find_by(company: company1).scopes).to eq([ 'all:access' ])
        expect(user.memberships.find_by(company: company2).scopes).to contain_exactly('products:read', 'orders:read')
        expect(user.memberships.find_by(company: company3).scopes).to eq([ 'products:read' ])
      end
    end

    context 'company with team structure' do
      let(:company) { create(:company) }
      let(:owner) { create(:user) }
      let(:admin1) { create(:user) }
      let(:admin2) { create(:user) }
      let(:member1) { create(:user) }
      let(:member2) { create(:user) }
      let(:member3) { create(:user) }

      before do
        create(:membership, user: owner, company: company, role: 'owner')
        create(:membership, user: admin1, company: company, role: 'admin')
        create(:membership, user: admin2, company: company, role: 'admin')
        create(:membership, user: member1, company: company, role: 'member')
        create(:membership, user: member2, company: company, role: 'member')
        create(:membership, user: member3, company: company, role: 'member')
      end

      it 'has correct team structure' do
        expect(company.memberships.count).to eq(6)
        expect(company.memberships.owners.count).to eq(1)
        expect(company.memberships.admins.count).to eq(2)
        expect(company.memberships.where(role: 'member').count).to eq(3)
      end

      it 'can identify members by role' do
        expect(company.memberships.find_by(user: owner).owner?).to be true
        expect(company.memberships.find_by(user: admin1).admin?).to be true
        expect(company.memberships.find_by(user: member1).member?).to be true
      end
    end

    context 'scope evolution over time' do
      let(:membership) { create(:membership, scopes: [ 'products:read' ]) }

      it 'can progressively add scopes' do
        membership.add_scope('products:write')
        expect(membership.scopes).to contain_exactly('products:read', 'products:write')

        membership.add_scope('orders:read')
        expect(membership.scopes).to contain_exactly('products:read', 'products:write', 'orders:read')

        membership.add_scope('orders:write')
        expect(membership.scopes).to contain_exactly('products:read', 'products:write', 'orders:read', 'orders:write')
      end

      it 'can revoke scopes' do
        membership.update(scopes: [ 'products:read', 'products:write', 'orders:read', 'orders:write' ])

        membership.remove_scope('products:write')
        expect(membership.scopes).to contain_exactly('products:read', 'orders:read', 'orders:write')

        membership.remove_scope('orders:write')
        expect(membership.scopes).to contain_exactly('products:read', 'orders:read')
      end
    end
  end

  describe 'active status' do
    let(:membership) { create(:membership) }

    it 'can be deactivated' do
      membership.update(active: false)
      expect(membership.active).to be false
    end

    it 'can be reactivated' do
      membership.update(active: false)
      membership.update(active: true)
      expect(membership.active).to be true
    end

    it 'inactive memberships are excluded from active scope' do
      active_membership = create(:membership, active: true)
      inactive_membership = create(:membership, active: false)

      expect(Membership.active).to include(active_membership)
      expect(Membership.active).not_to include(inactive_membership)
    end
  end

  describe 'timestamps' do
    let(:membership) { create(:membership) }

    it 'sets created_at on creation' do
      expect(membership.created_at).to be_present
      expect(membership.created_at).to be_within(1.second).of(Time.current)
    end

    it 'sets updated_at on creation' do
      expect(membership.updated_at).to be_present
      expect(membership.updated_at).to be_within(1.second).of(Time.current)
    end

    it 'updates updated_at on modification' do
      original_time = membership.updated_at
      sleep 0.1
      membership.update(role: 'admin')
      expect(membership.updated_at).to be > original_time
    end
  end

  describe 'deletion behavior' do
    let(:user) { create(:user) }
    let(:company) { create(:company) }
    let(:membership) { create(:membership, user: user, company: company) }

    it 'can be deleted independently' do
      membership_id = membership.id
      membership.destroy

      expect(Membership.find_by(id: membership_id)).to be_nil
      expect(User.find_by(id: user.id)).to be_present
      expect(Company.find_by(id: company.id)).to be_present
    end

    it 'is deleted when user is destroyed' do
      membership # create the membership
      expect {
        user.destroy
      }.to change { Membership.count }.by(-1)
    end

    it 'is deleted when company is destroyed' do
      membership # create the membership
      expect {
        company.destroy
      }.to change { Membership.count }.by(-1)
    end
  end
end
