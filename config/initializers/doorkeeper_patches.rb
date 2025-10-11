# frozen_string_literal: true

# This file adds compatibility patches for Doorkeeper

Rails.application.config.to_prepare do
  # Add by_token method for backward compatibility with Doorkeeper 5.x tests
  # Newer versions use find_by_token instead
  Doorkeeper::AccessToken.class_eval do
    def self.by_token(token)
      find_by_token(token)
    end

    # Add matching_token_for method for Rails 8 compatibility
    # This method finds an existing token that matches the given parameters
    def self.matching_token_for(application, resource_owner, scopes, custom_attributes: nil, include_expired: true)
      # Handle both objects with .id and raw IDs
      app_id = application.respond_to?(:id) ? application&.id : application
      owner_id = resource_owner.respond_to?(:id) ? resource_owner&.id : resource_owner

      tokens = where(
        application_id: app_id,
        resource_owner_id: owner_id,
        revoked_at: nil
      )

      # Filter out expired tokens unless include_expired is true
      unless include_expired
        tokens = tokens.where("expires_in IS NULL OR (created_at + (expires_in || ' seconds')::interval) > ?", Time.current)
      end

      # Find token matching scopes
      tokens.detect do |token|
        token.scopes.to_s == scopes.to_s
      end
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

    # Add plaintext_token method for JWT compatibility
    # When using JWT, the token response needs the actual JWT, not the database token
    unless instance_methods.include?(:plaintext_token)
      def plaintext_token
        # If JWT generator is configured, generate the JWT token
        if Doorkeeper.config.access_token_generator == "::Doorkeeper::JWT"
          # Generate JWT using the configured JWT settings
          # Note: scopes are stored as string in DB, need to convert back to Scopes object
          Doorkeeper::JWT.generate(
            resource_owner: User.find_by(id: resource_owner_id),
            scopes: Doorkeeper::OAuth::Scopes.from_string(scopes.to_s),
            application: Doorkeeper::Application.find_by(id: application_id),
            token: self
          )
        else
          # For non-JWT tokens, return the database token value
          token
        end
      end
    end

    # Add token_type method for OAuth token response
    unless instance_methods.include?(:token_type)
      def token_type
        "Bearer"
      end
    end

    # Add expires_in_seconds method for OAuth token response
    unless instance_methods.include?(:expires_in_seconds)
      def expires_in_seconds
        expires_in
      end
    end

    # Add plaintext_refresh_token method for OAuth token response with refresh tokens
    unless instance_methods.include?(:plaintext_refresh_token)
      def plaintext_refresh_token
        refresh_token
      end
    end

    # Add scopes_string method for OAuth token response
    unless instance_methods.include?(:scopes_string)
      def scopes_string
        scopes.to_s
      end
    end

    # Add find_or_create_for method for Rails 8 compatibility
    unless respond_to?(:find_or_create_for)
      def self.find_or_create_for(application:, resource_owner:, scopes:, **token_attributes)
        # Try to find existing token
        token = matching_token_for(application, resource_owner, scopes, include_expired: false)

        # Create new token if not found or if custom attributes differ
        if token.nil? || (token_attributes.present? && !token_attributes_match?(token, token_attributes))
          # Handle both objects with .id and raw IDs
          app_id = application.respond_to?(:id) ? application&.id : application
          owner_id = resource_owner.respond_to?(:id) ? resource_owner&.id : resource_owner

          # Filter out attributes that don't exist on the model
          valid_attributes = token_attributes.select { |key, _| column_names.include?(key.to_s) }

          # Generate a unique random token
          # When using JWT (access_token_generator "::Doorkeeper::JWT"), the actual JWT
          # is generated on-the-fly during API responses. The database token is just an identifier.
          token_value = Doorkeeper::OAuth::Helpers::UniqueToken.generate

          # Create the access token record
          token = create!(
            application_id: app_id,
            resource_owner_id: owner_id,
            token: token_value,
            scopes: scopes.to_s,
            **valid_attributes
          )
        end

        token
      end

      def self.token_attributes_match?(token, attributes)
        # Filter to only check attributes that exist on the model
        valid_attributes = attributes.select { |key, _| column_names.include?(key.to_s) }
        valid_attributes.all? { |key, value| token.send(key) == value }
      end
    end
  end
end
