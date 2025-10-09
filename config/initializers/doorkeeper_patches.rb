# frozen_string_literal: true

# This file adds compatibility patches for Doorkeeper

Rails.application.config.to_prepare do
  # Add by_token method for backward compatibility with Doorkeeper 5.x tests
  # Newer versions use find_by_token instead
  Doorkeeper::AccessToken.class_eval do
    def self.by_token(token)
      find_by_token(token)
    end

    # Add revoke_previous_refresh_token! if it doesn't exist
    unless instance_methods.include?(:revoke_previous_refresh_token!)
      def revoke_previous_refresh_token!
        # No-op for test environment or when use_refresh_token is disabled
        return true unless Doorkeeper.configuration.refresh_token_enabled?

        # Find and revoke previous refresh token if exists
        return true unless previous_refresh_token.present?

        # Find the token object by the refresh token string and revoke it
        token = Doorkeeper::AccessToken.find_by(refresh_token: previous_refresh_token)
        token&.revoke
      end
    end

    # Add revoked? method if it doesn't exist
    unless instance_methods.include?(:revoked?)
      def revoked?
        revoked_at.present?
      end
    end

    # Add expired? method if it doesn't exist
    unless instance_methods.include?(:expired?)
      def expired?
        return false if expires_in.nil?

        created_at + expires_in.seconds < Time.current
      end
    end

    # Add revoke method if it doesn't exist
    unless instance_methods.include?(:revoke)
      def revoke
        update_column(:revoked_at, Time.current) unless revoked?
      end
    end

    # Add acceptable? method if it doesn't exist
    unless instance_methods.include?(:acceptable?)
      def acceptable?(scopes = nil)
        # Token is acceptable if it's not revoked and not expired
        return false if revoked?
        return false if expired?

        # If no scopes required, token is acceptable
        return true if scopes.nil? || scopes.to_s.empty?

        # Check if token has all required scopes
        required_scopes = Doorkeeper::OAuth::Scopes.from_array(scopes)
        token_scopes = Doorkeeper::OAuth::Scopes.from_string(self.scopes.to_s)
        required_scopes.all? { |scope| token_scopes.exists?(scope) }
      end
    end
  end
end
