# frozen_string_literal: true

Doorkeeper.configure do
  # Change the ORM that doorkeeper will use (requires ORM extensions installed).
  orm :active_record

  # Use JWT for access tokens (except in test where we use plain tokens)
  access_token_generator "::Doorkeeper::JWT" unless Rails.env.test?

  # Token expiration
  access_token_expires_in 1.hour
  use_refresh_token

  # Resource owner authenticator
  # This block will be called to check whether the resource owner is authenticated or not.
  resource_owner_authenticator do
    current_user || redirect_to(new_user_session_path)
  end

  # Resource owner from credentials (for password grant)
  resource_owner_from_credentials do |routes|
    user = User.find_for_database_authentication(email: params[:username])
    if user&.valid_password?(params[:password])
      user
    end
  end

  # Grant flows
  grant_flows %w[authorization_code client_credentials password]

  # Skip authorization for trusted apps
  skip_authorization do |resource_owner, client|
    client.application.trusted?
  end

  # Enable application ownership
  enable_application_owner confirmation: false

  # Define access token scopes
  default_scopes  :public
  optional_scopes :write, :update, :admin

  # Force SSL in production
  force_ssl_in_redirect_uri Rails.env.production?

  # WWW-Authenticate Realm
  realm "Authlift"
end

# JWT Configuration
Doorkeeper::JWT.configure do
  # Token payload
  token_payload do |opts|
    user = opts[:resource_owner]
    application = opts[:application]

    # If there's no resource_owner, try to find it by resource_owner_id
    if user.nil? && opts[:token]&.resource_owner_id
      user = User.find_by(id: opts[:token].resource_owner_id)
    end

    # Skip JWT payload if no user found (for testing or client_credentials grant)
    next {} unless user

    payload = {
      # Standard JWT claims
      iss: ENV["AUTHLIFT_URL"],                    # Issuer
      sub: user.id.to_s,                           # Subject (user ID)
      aud: application&.uid,                       # Audience (client app)
      iat: Time.now.to_i,                          # Issued at
      exp: Time.now.to_i + opts[:token].expires_in, # Expiration
      jti: opts[:token].token,                     # JWT ID

      # Custom claims
      user: {
        id: user.id,
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name,
        locale: user.locale
      },

      # Company context
      company: if user.current_company
        {
          id: user.current_company.id,
          code: user.current_company.code,
          name: user.current_company.name,
          logo_code: user.current_company.logo_code
        }
               else
        nil
               end,

      # Membership info
      membership: if user.current_membership
        {
          role: user.current_membership.role,
          scopes: user.current_membership.scopes
        }
                  else
        nil
                  end,

      # Token scopes
      scopes: opts[:scopes].to_a
    }

    payload
  end

  # Use RS256 (asymmetric) for security
  signing_method :rs256

  # Load private key from credentials
  secret_key lambda {
    private_key_content = Rails.application.credentials.dig(:doorkeeper, :private_key)
    OpenSSL::PKey::RSA.new(private_key_content) if private_key_content
  }

  # Encryption (optional, for extra security)
  # encryption_method :dir
  # encryption_algorithm :a128gcm
end
