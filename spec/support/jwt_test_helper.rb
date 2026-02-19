# frozen_string_literal: true

# JWT Test Helper Module
# Provides utility methods for generating and validating JWT tokens in security tests
module JwtTestHelper
  # Generate RSA key pair for testing
  # In production, these are stored in Rails credentials
  def self.generate_test_keys
    rsa_key = OpenSSL::PKey::RSA.generate(2048)
    {
      private_key: rsa_key.to_pem,
      public_key: rsa_key.public_key.to_pem
    }
  end

  # Generate a JWT token with custom payload
  # @param user [User] The user to generate token for
  # @param payload_overrides [Hash] Custom claims to override defaults
  # @return [String] JWT token
  def generate_test_jwt(user, payload_overrides = {})
    private_key = OpenSSL::PKey::RSA.new(
      Rails.application.credentials.dig(:doorkeeper, :private_key)
    )

    # Create DB-backed token for revocation check unless jti is explicitly overridden
    unless payload_overrides.key?(:jti)
      app = Doorkeeper::Application.first || FactoryBot.create(:oauth_application)
      db_token = FactoryBot.create(:oauth_access_token, application_id: app.id, resource_owner_id: user.id)
      payload_overrides[:jti] = db_token.token
    end

    default_payload = {
      iss: ENV['AUTHLIFT_URL'],
      sub: user.id.to_s,
      aud: 'test-client',
      iat: Time.now.to_i,
      exp: Time.now.to_i + 3600,
      user: {
        id: user.id,
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name
      }
    }

    payload = default_payload.merge(payload_overrides)
    JWT.encode(payload, private_key, 'RS256')
  end

  # Decode and verify a JWT token
  # @param token [String] The JWT token to decode
  # @return [Hash] Decoded payload
  def decode_test_jwt(token)
    public_key = OpenSSL::PKey::RSA.new(
      Rails.application.credentials.dig(:doorkeeper, :public_key)
    )

    JWT.decode(
      token,
      public_key,
      true,
      {
        algorithm: 'RS256',
        verify_expiration: true,
        verify_iat: true
      }
    ).first
  end

  # Generate an expired JWT token for testing
  # @param user [User] The user to generate token for
  # @param expired_seconds_ago [Integer] How long ago the token expired
  # @return [String] Expired JWT token
  def generate_expired_jwt(user, expired_seconds_ago: 3600)
    generate_test_jwt(user,
                      iat: Time.now.to_i - (expired_seconds_ago + 7200),
                      exp: Time.now.to_i - expired_seconds_ago)
  end

  # Generate a JWT with invalid issuer
  # @param user [User] The user to generate token for
  # @param invalid_issuer [String] The invalid issuer to use
  # @return [String] JWT token with invalid issuer
  def generate_jwt_with_invalid_issuer(user, invalid_issuer: 'https://evil.com')
    generate_test_jwt(user, iss: invalid_issuer)
  end

  # Generate a JWT signed with wrong key
  # @param user [User] The user to generate token for
  # @return [String] JWT token signed with wrong key
  def generate_jwt_with_wrong_key(user)
    wrong_key = OpenSSL::PKey::RSA.generate(2048)

    payload = {
      iss: ENV['AUTHLIFT_URL'],
      sub: user.id.to_s,
      aud: 'test-client',
      iat: Time.now.to_i,
      exp: Time.now.to_i + 3600,
      jti: SecureRandom.hex(32)
    }

    JWT.encode(payload, wrong_key, 'RS256')
  end
end

# Include in RSpec configuration
RSpec.configure do |config|
  config.include JwtTestHelper, type: :request
  config.include JwtTestHelper, type: :controller
end
