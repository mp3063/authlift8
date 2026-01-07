# frozen_string_literal: true

# SessionVersionService
#
# Publishes session version updates to Redis when user, company, or
# customer_group data changes. Client applications check these versions
# to determine if they need to refresh their cached profile data.
#
# Redis Keys:
#   session_version:user:{user_id}
#   session_version:company:{company_id}
#   session_version:customer_group:{company_id}
#
# Usage:
#   SessionVersionService.invalidate_user(user)
#   SessionVersionService.invalidate_company(company)
#   SessionVersionService.invalidate_customer_groups(company)
#
class SessionVersionService
  REDIS_NAMESPACE = 'session_version'
  VERSION_TTL = 7.days.to_i  # Auto-cleanup old keys

  class << self
    # Invalidate user session version
    # Called when user attributes change (email, name, locale, etc.)
    #
    # @param user [User] The user whose session should be invalidated
    def invalidate_user(user)
      set_version(:user, user.id)
      # Also invalidate company context if user has one
      invalidate_company(user.current_company) if user.current_company
    end

    # Invalidate company session version
    # Called when company attributes change
    #
    # @param company [Company] The company whose sessions should be invalidated
    def invalidate_company(company)
      return unless company
      set_version(:company, company.id)
    end

    # Invalidate customer groups version for a company
    # Called when customer groups are created, updated, or destroyed
    #
    # @param company [Company] The company whose customer groups changed
    def invalidate_customer_groups(company)
      return unless company
      set_version(:customer_group, company.id)
    end

    # Get current version for an entity
    # Used by client apps to check if their cached data is current
    #
    # @param entity_type [Symbol] :user, :company, or :customer_group
    # @param entity_id [Integer] The ID of the entity
    # @return [Integer] The version timestamp (milliseconds) or 0 if not set
    def get_version(entity_type, entity_id)
      key = build_key(entity_type, entity_id)
      redis.get(key)&.to_i || 0
    end

    private

    def set_version(entity_type, entity_id)
      key = build_key(entity_type, entity_id)
      version = (Time.current.to_f * 1000).to_i  # Millisecond precision

      redis.setex(key, VERSION_TTL, version)

      Rails.logger.info(
        "[SessionVersion] Invalidated #{entity_type}:#{entity_id} version=#{version}"
      )

      version
    end

    def build_key(entity_type, entity_id)
      "#{REDIS_NAMESPACE}:#{entity_type}:#{entity_id}"
    end

    def redis
      @redis ||= Redis.new(
        url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')
      )
    end
  end
end
