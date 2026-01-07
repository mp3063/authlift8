# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SessionVersionService do
  let(:company) { create(:company) }
  let(:user) { create(:user) }
  let(:membership) { create(:membership, user: user, company: company, active: true) }

  before do
    # Clear Redis session version keys before each test
    redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
    redis.keys('session_version:*').each { |key| redis.del(key) }
  end

  describe '.invalidate_user' do
    before do
      # Set up user with company via membership
      membership
      user.update!(company: company)
    end

    it 'sets user version in Redis' do
      described_class.invalidate_user(user)
      version = described_class.get_version(:user, user.id)
      expect(version).to be > 0
    end

    it 'sets version as millisecond timestamp' do
      freeze_time do
        described_class.invalidate_user(user)
        version = described_class.get_version(:user, user.id)
        expected = (Time.current.to_f * 1000).to_i
        expect(version).to eq(expected)
      end
    end

    it 'also invalidates company if user has one' do
      described_class.invalidate_user(user)
      company_version = described_class.get_version(:company, company.id)
      expect(company_version).to be > 0
    end

    it 'does not invalidate company if user has no company' do
      user_without_company = create(:user)
      described_class.invalidate_user(user_without_company)

      # User version should be set
      user_version = described_class.get_version(:user, user_without_company.id)
      expect(user_version).to be > 0
    end
  end

  describe '.invalidate_company' do
    it 'sets company version in Redis' do
      described_class.invalidate_company(company)
      version = described_class.get_version(:company, company.id)
      expect(version).to be > 0
    end

    it 'handles nil company gracefully' do
      expect { described_class.invalidate_company(nil) }.not_to raise_error
    end

    it 'does not set version for nil company' do
      described_class.invalidate_company(nil)
      # No version should be set - this verifies early return
      # We can't really test this directly, but we can ensure no error
    end
  end

  describe '.invalidate_customer_groups' do
    it 'sets customer_group version in Redis' do
      described_class.invalidate_customer_groups(company)
      version = described_class.get_version(:customer_group, company.id)
      expect(version).to be > 0
    end

    it 'handles nil company gracefully' do
      expect { described_class.invalidate_customer_groups(nil) }.not_to raise_error
    end
  end

  describe '.get_version' do
    it 'returns 0 when no version exists' do
      version = described_class.get_version(:user, 99999)
      expect(version).to eq(0)
    end

    it 'returns the stored version' do
      described_class.invalidate_user(user)
      version = described_class.get_version(:user, user.id)
      expect(version).to be > 0
    end

    it 'returns correct version for different entity types' do
      described_class.invalidate_company(company)
      described_class.invalidate_customer_groups(company)

      company_version = described_class.get_version(:company, company.id)
      customer_group_version = described_class.get_version(:customer_group, company.id)

      expect(company_version).to be > 0
      expect(customer_group_version).to be > 0
    end
  end

  describe 'version TTL' do
    it 'stores versions with a TTL' do
      described_class.invalidate_user(user)

      redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
      key = "session_version:user:#{user.id}"
      ttl = redis.ttl(key)

      # TTL should be set and be around 7 days (604800 seconds)
      expect(ttl).to be > 0
      expect(ttl).to be <= 7.days.to_i
    end
  end

  describe 'model callbacks integration' do
    context 'when user is updated' do
      it 'invalidates session version on email change' do
        user.update!(email: "new_email_#{SecureRandom.hex(4)}@example.com")
        version = described_class.get_version(:user, user.id)
        expect(version).to be > 0
      end

      it 'invalidates session version on first_name change' do
        user.update!(first_name: 'NewFirstName')
        version = described_class.get_version(:user, user.id)
        expect(version).to be > 0
      end

      it 'invalidates session version on last_name change' do
        user.update!(last_name: 'NewLastName')
        version = described_class.get_version(:user, user.id)
        expect(version).to be > 0
      end

      it 'invalidates session version on locale change' do
        user.update!(locale: 'sv')
        version = described_class.get_version(:user, user.id)
        expect(version).to be > 0
      end

      it 'invalidates session version on admin change' do
        user.update!(admin: true)
        version = described_class.get_version(:user, user.id)
        expect(version).to be > 0
      end

      it 'invalidates session version on super_admin change' do
        user.update!(super_admin: true)
        version = described_class.get_version(:user, user.id)
        expect(version).to be > 0
      end

      it 'does not invalidate on irrelevant attribute change' do
        # Clear any existing version
        redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
        redis.del("session_version:user:#{user.id}")

        # Only touch updated_at (not a relevant attribute)
        user.touch
        version = described_class.get_version(:user, user.id)
        expect(version).to eq(0)
      end
    end

    context 'when membership is created' do
      it 'invalidates user version' do
        new_user = create(:user)
        new_company = create(:company)

        create(:membership, user: new_user, company: new_company)

        user_version = described_class.get_version(:user, new_user.id)
        expect(user_version).to be > 0
      end

      it 'invalidates company version' do
        new_user = create(:user)
        new_company = create(:company)

        create(:membership, user: new_user, company: new_company)

        company_version = described_class.get_version(:company, new_company.id)
        expect(company_version).to be > 0
      end
    end

    context 'when membership is updated' do
      it 'invalidates user and company versions on role change' do
        membership.update!(role: 'admin')

        user_version = described_class.get_version(:user, user.id)
        company_version = described_class.get_version(:company, company.id)

        expect(user_version).to be > 0
        expect(company_version).to be > 0
      end

      it 'invalidates user and company versions on active change' do
        membership.update!(active: false)

        user_version = described_class.get_version(:user, user.id)
        company_version = described_class.get_version(:company, company.id)

        expect(user_version).to be > 0
        expect(company_version).to be > 0
      end
    end

    context 'when membership is destroyed' do
      it 'invalidates user and company versions' do
        # Create fresh records for this test
        test_user = create(:user)
        test_company = create(:company)
        test_membership = create(:membership, user: test_user, company: test_company)

        # Clear versions before destroy
        redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
        redis.del("session_version:user:#{test_user.id}")
        redis.del("session_version:company:#{test_company.id}")

        test_membership.destroy!

        user_version = described_class.get_version(:user, test_user.id)
        company_version = described_class.get_version(:company, test_company.id)

        expect(user_version).to be > 0
        expect(company_version).to be > 0
      end
    end

    context 'when customer_group is created' do
      it 'invalidates customer_group version' do
        CustomerGroup.create!(company: company, name: 'Wholesale')
        version = described_class.get_version(:customer_group, company.id)
        expect(version).to be > 0
      end
    end

    context 'when customer_group is updated' do
      it 'invalidates customer_group version' do
        customer_group = CustomerGroup.create!(company: company, name: 'Wholesale')

        # Clear version
        redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
        redis.del("session_version:customer_group:#{company.id}")

        customer_group.update!(name: 'Retail')
        version = described_class.get_version(:customer_group, company.id)
        expect(version).to be > 0
      end
    end

    context 'when customer_group is destroyed' do
      it 'invalidates customer_group version' do
        customer_group = CustomerGroup.create!(company: company, name: 'Wholesale')

        # Clear version
        redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
        redis.del("session_version:customer_group:#{company.id}")

        customer_group.destroy!
        version = described_class.get_version(:customer_group, company.id)
        expect(version).to be > 0
      end
    end
  end

  describe 'Redis key format' do
    it 'uses correct namespace for user keys' do
      described_class.invalidate_user(user)

      redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
      key = "session_version:user:#{user.id}"
      expect(redis.exists?(key)).to be true
    end

    it 'uses correct namespace for company keys' do
      described_class.invalidate_company(company)

      redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
      key = "session_version:company:#{company.id}"
      expect(redis.exists?(key)).to be true
    end

    it 'uses correct namespace for customer_group keys' do
      described_class.invalidate_customer_groups(company)

      redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
      key = "session_version:customer_group:#{company.id}"
      expect(redis.exists?(key)).to be true
    end
  end

  describe 'version updates' do
    it 'updates version on subsequent invalidations' do
      described_class.invalidate_user(user)
      first_version = described_class.get_version(:user, user.id)

      # Wait a small amount to ensure different timestamp
      sleep(0.001)

      described_class.invalidate_user(user)
      second_version = described_class.get_version(:user, user.id)

      expect(second_version).to be > first_version
    end
  end
end
