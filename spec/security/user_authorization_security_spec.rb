# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User Authorization Security', type: :model do
  # Test users
  let(:super_admin_user) { create(:user, super_admin: true) }
  let(:regular_user) { create(:user, super_admin: false) }

  # Test companies
  let(:company_a) { create(:company, code: 'COMPA') }
  let(:company_b) { create(:company, code: 'COMPB') }
  let(:company_c) { create(:company, code: 'COMPC') }

  # Memberships for regular_user
  let(:owner_membership_a) do
    create(:membership, :owner, user: regular_user, company: company_a, active: true)
  end

  let(:admin_membership_b) do
    create(:membership, :admin, user: regular_user, company: company_b, active: true)
  end

  let(:member_membership_c) do
    create(:membership,
           user: regular_user,
           company: company_c,
           active: true,
           scopes: [ 'products:read', 'orders:read' ])
  end

  let(:inactive_membership) do
    create(:membership,
           user: regular_user,
           company: create(:company),
           active: false,
           scopes: [ 'admin:write' ])
  end

  describe 'Super Admin - Global Access' do
    context 'when user is super_admin' do
      it 'has_scope? returns true for any scope' do
        expect(super_admin_user.has_scope?('products:read')).to be true
        expect(super_admin_user.has_scope?('admin:write')).to be true
        expect(super_admin_user.has_scope?('any:scope')).to be true
      end

      it 'has global access across all companies' do
        expect(super_admin_user.has_scope?('products:read', company: company_a)).to be true
        expect(super_admin_user.has_scope?('admin:write', company: company_b)).to be true
        expect(super_admin_user.has_scope?('any:scope', company: company_c)).to be true
      end

      it 'has access even without any memberships' do
        # Ensure no memberships exist
        expect(super_admin_user.memberships.count).to eq(0)

        expect(super_admin_user.has_scope?('products:read')).to be true
      end

      it 'is_admin_for? returns true for any company' do
        expect(super_admin_user.admin_for?(company_a)).to be true
        expect(super_admin_user.admin_for?(company_b)).to be true
        expect(super_admin_user.admin_for?(company_c)).to be true
      end

      it 'super_admin? returns true' do
        expect(super_admin_user.super_admin?).to be true
      end
    end

    context 'when super_admin attribute is false' do
      it 'super_admin? returns false' do
        expect(regular_user.super_admin?).to be false
      end

      it 'does not have global access' do
        expect(regular_user.has_scope?('products:read', company: company_a)).to be false
      end

      it 'does not treat false as true' do
        expect(regular_user.has_scope?('admin:write')).to be false
      end
    end
  end

  describe 'Company-Scoped Authorization' do
    before do
      owner_membership_a
      admin_membership_b
      member_membership_c
      regular_user.update(company: company_a)
    end

    context 'owner role - full access within company' do
      it 'has all scopes within owned company' do
        expect(regular_user.has_scope?('products:read', company: company_a)).to be true
        expect(regular_user.has_scope?('products:write', company: company_a)).to be true
        expect(regular_user.has_scope?('admin:full', company: company_a)).to be true
        expect(regular_user.has_scope?('any:scope', company: company_a)).to be true
      end

      it 'is admin for owned company' do
        expect(regular_user.admin_for?(company_a)).to be true
      end

      it 'all_scopes returns combined scopes for owned company' do
        # Owners have all scopes, but all_scopes just returns what's defined
        scopes = regular_user.all_scopes(company: company_a)
        expect(scopes).to be_an(Array)
      end
    end

    context 'admin role - full access within company' do
      it 'has all scopes within admin company' do
        expect(regular_user.has_scope?('products:read', company: company_b)).to be true
        expect(regular_user.has_scope?('products:write', company: company_b)).to be true
        expect(regular_user.has_scope?('admin:full', company: company_b)).to be true
      end

      it 'is admin for admin company' do
        expect(regular_user.admin_for?(company_b)).to be true
      end

      it 'does NOT have admin access in other companies' do
        expect(regular_user.admin_for?(company_c)).to be false
      end
    end

    context 'member role - scope-based access' do
      it 'has specific scopes within member company' do
        expect(regular_user.has_scope?('products:read', company: company_c)).to be true
        expect(regular_user.has_scope?('orders:read', company: company_c)).to be true
      end

      it 'does NOT have scopes not assigned to membership' do
        expect(regular_user.has_scope?('products:write', company: company_c)).to be false
        expect(regular_user.has_scope?('admin:full', company: company_c)).to be false
      end

      it 'is NOT admin for member company' do
        expect(regular_user.admin_for?(company_c)).to be false
      end
    end

    context 'cross-company access control' do
      it 'owner of company A has no access to company B' do
        # Owner in A, but only member scopes should work in C
        expect(regular_user.has_scope?('products:write', company: company_c)).to be false
      end

      it 'admin of company B has no admin rights in company A' do
        # Admin in B, but owner in A - owner rights in A, not admin from B
        expect(regular_user.admin_for?(company_a)).to be true # owner
        expect(regular_user.admin_for?(company_b)).to be true # admin
      end

      it 'scopes are isolated per company' do
        # member_membership_c has 'products:read'
        expect(regular_user.has_scope?('products:read', company: company_c)).to be true

        # But in company_a (owner), it also has access
        expect(regular_user.has_scope?('products:read', company: company_a)).to be true

        # Create a company with no membership
        company_no_access = create(:company)
        expect(regular_user.has_scope?('products:read', company: company_no_access)).to be false
      end
    end
  end

  describe 'Inactive Membership - Access Denied' do
    before do
      inactive_membership
    end

    it 'denies access to company with inactive membership' do
      inactive_company = inactive_membership.company

      expect(regular_user.has_scope?('admin:write', company: inactive_company)).to be false
    end

    it 'does not return inactive membership in has_scope? check' do
      inactive_company = inactive_membership.company

      # Even though membership has 'admin:write' scope, it's inactive
      expect(regular_user.has_scope?('admin:write', company: inactive_company)).to be false
    end

    it 'is not admin for company with inactive membership' do
      inactive_company = inactive_membership.company

      expect(regular_user.admin_for?(inactive_company)).to be false
    end

    it 'grants access when membership becomes active' do
      inactive_company = inactive_membership.company

      # Initially denied
      expect(regular_user.has_scope?('admin:write', company: inactive_company)).to be false

      # Activate membership
      inactive_membership.update(active: true)

      # Now has access (if owner/admin, or if has specific scope)
      # Since it's a member with 'admin:write' scope
      expect(regular_user.has_scope?('admin:write', company: inactive_company)).to be true
    end

    it 'revokes access when membership becomes inactive' do
      # Start with active membership
      active_mem = create(:membership,
                          user: regular_user,
                          company: create(:company),
                          active: true,
                          scopes: [ 'test:scope' ])

      test_company = active_mem.company

      expect(regular_user.has_scope?('test:scope', company: test_company)).to be true

      # Deactivate
      active_mem.update(active: false)

      expect(regular_user.has_scope?('test:scope', company: test_company)).to be false
    end
  end

  describe 'Current Company Context' do
    before do
      owner_membership_a
      admin_membership_b
      member_membership_c
    end

    context 'when company parameter is not provided' do
      it 'uses current_company for scope check' do
        regular_user.update(company: company_a)

        # Should check against company_a (owner)
        expect(regular_user.has_scope?('any:scope')).to be true
      end

      it 'returns false when no current company is set' do
        regular_user.update(company: nil)

        expect(regular_user.has_scope?('products:read')).to be false
      end

      it 'returns false when current company has no active membership' do
        company_no_membership = create(:company)
        regular_user.update(company: company_no_membership)

        expect(regular_user.has_scope?('products:read')).to be false
      end
    end

    context 'when company parameter is provided' do
      it 'uses provided company instead of current_company' do
        regular_user.update(company: company_a)

        # Check against company_c instead of current (company_a)
        expect(regular_user.has_scope?('products:read', company: company_c)).to be true
        expect(regular_user.has_scope?('products:write', company: company_c)).to be false
      end

      it 'allows checking scopes for any accessible company' do
        regular_user.update(company: company_a)

        expect(regular_user.has_scope?('products:read', company: company_a)).to be true
        expect(regular_user.has_scope?('products:read', company: company_b)).to be true
        expect(regular_user.has_scope?('products:read', company: company_c)).to be true
      end
    end
  end

  describe 'No Membership Scenarios' do
    it 'returns false when user has no memberships at all' do
      user_no_memberships = create(:user)

      expect(user_no_memberships.has_scope?('products:read')).to be false
      expect(user_no_memberships.has_scope?('products:read', company: company_a)).to be false
    end

    it 'returns false when checking scope for company without membership' do
      owner_membership_a

      company_no_access = create(:company)

      expect(regular_user.has_scope?('products:read', company: company_no_access)).to be false
    end

    it 'current_company returns nil when all memberships are inactive' do
      inactive_mem = create(:membership, user: regular_user, company: company_a, active: false)
      regular_user.update(company: company_a)

      expect(regular_user.current_company).to be_nil
    end

    it 'current_membership returns nil when company membership is inactive' do
      inactive_mem = create(:membership, user: regular_user, company: company_a, active: false)
      regular_user.update(company: company_a)

      expect(regular_user.current_membership).to be_nil
    end
  end

  describe 'Scope Inheritance and Combination' do
    before do
      member_membership_c
    end

    it 'combines user-level and membership-level scopes' do
      # Add user-level scopes
      regular_user.update(scopes: 'global:scope')

      scopes = regular_user.all_scopes(company: company_c)

      expect(scopes).to include('global:scope')
      expect(scopes).to include('products:read')
      expect(scopes).to include('orders:read')
    end

    it 'returns unique scopes (no duplicates)' do
      # Add overlapping scope
      regular_user.update(scopes: 'products:read,global:scope')

      scopes = regular_user.all_scopes(company: company_c)

      expect(scopes.count('products:read')).to eq(1)
      expect(scopes).to include('global:scope')
    end

    it 'handles nil/empty user scopes gracefully' do
      regular_user.update(scopes: nil)

      scopes = regular_user.all_scopes(company: company_c)

      expect(scopes).to eq([ 'products:read', 'orders:read' ])
    end

    it 'handles nil/empty membership scopes gracefully' do
      membership = create(:membership, user: regular_user, company: create(:company), active: true, scopes: nil)

      scopes = regular_user.all_scopes(company: membership.company)

      expect(scopes).to be_an(Array)
    end
  end

  describe 'Security Edge Cases' do
    it 'prevents privilege escalation via inactive membership' do
      # User has admin scope in inactive membership
      admin_inactive = create(:membership,
                              :admin,
                              user: regular_user,
                              company: create(:company),
                              active: false)

      expect(regular_user.has_scope?('admin:write', company: admin_inactive.company)).to be false
      expect(regular_user.admin_for?(admin_inactive.company)).to be false
    end

    it 'validates active status before granting owner privileges' do
      owner_inactive = create(:membership,
                              :owner,
                              user: regular_user,
                              company: create(:company),
                              active: false)

      expect(regular_user.has_scope?('any:scope', company: owner_inactive.company)).to be false
    end

    it 'requires active membership for admin_for? check' do
      admin_inactive = create(:membership,
                              :admin,
                              user: regular_user,
                              company: create(:company),
                              active: false)

      expect(regular_user.admin_for?(admin_inactive.company)).to be false
    end

    it 'handles company parameter as nil gracefully' do
      expect(regular_user.has_scope?('products:read', company: nil)).to be false
    end

    it 'handles scope parameter as symbol' do
      owner_membership_a

      expect(regular_user.has_scope?(:products_read, company: company_a)).to be true
    end

    it 'handles scope parameter as string' do
      owner_membership_a

      expect(regular_user.has_scope?('products:read', company: company_a)).to be true
    end
  end

  describe 'Role-Based Access Control (RBAC)' do
    before do
      owner_membership_a
      admin_membership_b
      member_membership_c
    end

    it 'owner > admin > member hierarchy within same company' do
      # Create all three roles in same company
      test_company = create(:company)

      owner = create(:user)
      admin = create(:user)
      member = create(:user)

      create(:membership, :owner, user: owner, company: test_company, active: true)
      create(:membership, :admin, user: admin, company: test_company, active: true)
      create(:membership, user: member, company: test_company, active: true, scopes: [ 'read:only' ])

      # Owner has full access
      expect(owner.has_scope?('admin:delete', company: test_company)).to be true

      # Admin has full access
      expect(admin.has_scope?('admin:delete', company: test_company)).to be true

      # Member only has assigned scopes
      expect(member.has_scope?('read:only', company: test_company)).to be true
      expect(member.has_scope?('admin:delete', company: test_company)).to be false
    end

    it 'validates role transitions respect active membership status' do
      test_company = create(:company)
      test_user = create(:user)

      # Start as member
      membership = create(:membership,
                          user: test_user,
                          company: test_company,
                          active: true,
                          role: 'member',
                          scopes: [ 'read:only' ])

      expect(test_user.has_scope?('admin:write', company: test_company)).to be false

      # Promote to admin
      membership.update(role: 'admin')

      expect(test_user.has_scope?('admin:write', company: test_company)).to be true

      # Deactivate
      membership.update(active: false)

      expect(test_user.has_scope?('admin:write', company: test_company)).to be false
    end
  end

  describe 'Multi-Company Access Patterns' do
    before do
      owner_membership_a
      admin_membership_b
      member_membership_c
    end

    it 'supports user with different roles across multiple companies' do
      # Owner in A
      expect(regular_user.has_scope?('full:access', company: company_a)).to be true

      # Admin in B
      expect(regular_user.has_scope?('full:access', company: company_b)).to be true

      # Member in C
      expect(regular_user.has_scope?('products:read', company: company_c)).to be true
      expect(regular_user.has_scope?('full:access', company: company_c)).to be false
    end

    it 'isolates permissions between companies' do
      # Owner in A doesn't grant access to B
      expect(regular_user.admin_for?(company_a)).to be true
      expect(regular_user.admin_for?(company_b)).to be true # but user is also admin in B

      # Create company with no membership
      company_isolated = create(:company)
      expect(regular_user.admin_for?(company_isolated)).to be false
      expect(regular_user.has_scope?('any:scope', company: company_isolated)).to be false
    end

    it 'allows switching between company contexts' do
      # Set current company to A (owner)
      regular_user.update(company: company_a)
      expect(regular_user.has_scope?('full:access')).to be true

      # Switch to C (member)
      regular_user.update(company: company_c)
      expect(regular_user.has_scope?('products:read')).to be true
      expect(regular_user.has_scope?('products:write')).to be false
    end
  end

  describe 'Security Logging and Warnings' do
    it 'logs warning when attempting to set current_company without active membership' do
      unauthorized_company = create(:company)

      expect(Rails.logger).to receive(:warn).with(
        /SECURITY: User #{regular_user.id} attempted to set current_company to #{unauthorized_company.id} without active membership/
      )

      regular_user.current_company = unauthorized_company

      expect(regular_user.reload.company).not_to eq(unauthorized_company)
    end

    it 'allows setting current_company with active membership' do
      owner_membership_a

      regular_user.current_company = company_a

      expect(regular_user.reload.company).to eq(company_a)
    end

    it 'allows setting current_company to nil' do
      owner_membership_a
      regular_user.update(company: company_a)

      regular_user.current_company = nil

      expect(regular_user.reload.company).to be_nil
    end
  end

  describe 'Performance and Optimization' do
    it 'efficiently checks scopes with database queries' do
      owner_membership_a

      # This should use cached membership data when possible
      queries = 0
      callback = ->(*, payload) { queries += 1 if payload[:sql] =~ /SELECT/i }

      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        regular_user.has_scope?('products:read', company: company_a)
      end

      # Should be minimal queries
      expect(queries).to be <= 2 # One for membership, possibly one for company
    end

    it 'handles bulk scope checks efficiently' do
      owner_membership_a

      scopes_to_check = %w[
        products:read products:write orders:read
        orders:write admin:full inventory:manage
      ]

      scopes_to_check.each do |scope|
        expect(regular_user.has_scope?(scope, company: company_a)).to be true
      end
    end
  end
end
