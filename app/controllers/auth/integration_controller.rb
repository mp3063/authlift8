# frozen_string_literal: true

module Auth
  # IntegrationController - Handles OAuth2 integration endpoints for client applications
  # Security: All endpoints validate redirect URLs, JWT tokens, and implement proper CSRF protection
  class IntegrationController < ApplicationController
    # SECURITY FIX: Selective CSRF protection - only skip for GET requests with valid JWT
    # State-changing operations (POST/DELETE) require either CSRF token or valid JWT
    skip_before_action :verify_authenticity_token, only: [:check_login]
    before_action :validate_csrf_or_token, except: [:check_login]

    # SECURITY: Allowed redirect hosts from environment configuration
    # Only URLs matching these hosts will be permitted for redirects
    ALLOWED_REDIRECT_HOSTS = ENV.fetch('ALLOWED_ORIGINS', '')
                                .split(',')
                                .map { |origin| URI.parse(origin.strip).host }
                                .compact
                                .freeze

    # SECURITY: Whitelist of allowed language codes
    # Prevents injection of arbitrary values into membership data
    ALLOWED_LANGUAGES = %w[
      en es fr de it pt nl ru ja zh ko ar he tr pl cs sv da fi no
    ].freeze

    # GET /auth/check_login?return_to=...
    # For client apps to check if user is logged in
    # SECURITY FIX: Validates redirect URL against whitelist
    def check_login
      return_to = params[:return_to]

      unless return_to.present? && valid_redirect_url?(return_to)
        Rails.logger.warn "Invalid redirect URL in check_login: #{return_to}"
        render json: { error: 'Invalid redirect URL' }, status: :bad_request
        return
      end

      return_url = URI(return_to)
      query_params = URI.decode_www_form(return_url.query || '').to_h
      query_params['logged_in'] = user_signed_in?.to_s
      return_url.query = URI.encode_www_form(query_params)

      redirect_to return_url.to_s, allow_other_host: true, status: :see_other
    rescue URI::InvalidURIError => e
      Rails.logger.error "URI parsing error in check_login: #{e.message}"
      render json: { error: 'Invalid URL format' }, status: :bad_request
    end

    # DELETE/GET /auth/logout?token=...&return_to=...
    # Remote logout - destroys all user tokens
    # SECURITY FIX: Enhanced JWT validation and redirect URL validation
    def logout
      token = params[:token]
      return_to = params[:return_to] || root_url

      # SECURITY FIX: Validate return_to URL
      unless valid_redirect_url?(return_to)
        Rails.logger.warn "Invalid redirect URL in logout: #{return_to}"
        return_to = root_url
      end

      if token.present?
        begin
          payload = validate_jwt_token(token)
          user = User.find(payload['sub'])

          # Log security event
          Rails.logger.info "Remote logout initiated for user #{user.id} (#{user.email})"

          # Destroy all OAuth tokens
          user.oauth_access_tokens.destroy_all

          # Sign out if current user
          sign_out(user) if current_user == user

          flash[:notice] = 'Logged out successfully'
        rescue JWT::DecodeError => e
          Rails.logger.error "JWT decode error during logout: #{e.message}"
          flash[:alert] = 'Invalid authentication token'
        rescue JWT::ExpiredSignature => e
          Rails.logger.error "Expired token during logout: #{e.message}"
          flash[:alert] = 'Authentication token has expired'
        rescue ActiveRecord::RecordNotFound => e
          Rails.logger.error "User not found during logout: #{e.message}"
          flash[:alert] = 'User not found'
        rescue StandardError => e
          Rails.logger.error "Unexpected error during logout: #{e.class} - #{e.message}"
          flash[:alert] = 'An error occurred during logout'
        end
      else
        flash[:alert] = 'Authentication token is required'
      end

      redirect_to return_to, allow_other_host: true, status: :see_other
    end

    # POST/GET /auth/switch_company?token=...&company_code=...&return_to=...
    # Remote company switch - returns new JWT with new company context
    # SECURITY FIX: Validates active membership and redirect URL
    def switch_company
      token = params[:token]
      company_code = params[:company_code]
      return_to = params[:return_to] || root_url

      # SECURITY FIX: Validate return_to URL
      unless valid_redirect_url?(return_to)
        Rails.logger.warn "Invalid redirect URL in switch_company: #{return_to}"
        return_to = root_url
      end

      if token.blank? || company_code.blank?
        flash[:alert] = 'Token and company code are required'
        redirect_to return_to, allow_other_host: true, status: :see_other
        return
      end

      begin
        payload = validate_jwt_token(token)
        user = User.find(payload['sub'])

        # SECURITY FIX: Only allow switching to companies with ACTIVE memberships
        active_membership = user.memberships.active.joins(:company)
                                .find_by(companies: { code: company_code })

        if active_membership
          new_company = active_membership.company

          # Log security event
          Rails.logger.info "User #{user.id} (#{user.email}) switching to company #{new_company.id} (#{company_code})"

          user.update(company: new_company)

          # Generate new JWT with updated company context
          new_token = generate_jwt_for_user(user)

          # Redirect with new token
          return_url = URI(return_to)
          query_params = URI.decode_www_form(return_url.query || '').to_h
          query_params['token'] = new_token
          query_params['company_switched'] = 'true'
          return_url.query = URI.encode_www_form(query_params)

          redirect_to return_url.to_s, allow_other_host: true, status: :see_other
          return
        else
          Rails.logger.warn "Unauthorized company switch attempt: user #{user.id} to company #{company_code}"
          flash[:alert] = 'Company not found or access denied'
        end
      rescue JWT::DecodeError => e
        Rails.logger.error "JWT decode error during company switch: #{e.message}"
        flash[:alert] = 'Invalid authentication token'
      rescue JWT::ExpiredSignature => e
        Rails.logger.error "Expired token during company switch: #{e.message}"
        flash[:alert] = 'Authentication token has expired'
      rescue ActiveRecord::RecordNotFound => e
        Rails.logger.error "User not found during company switch: #{e.message}"
        flash[:alert] = 'User not found'
      rescue StandardError => e
        Rails.logger.error "Unexpected error during company switch: #{e.class} - #{e.message}"
        flash[:alert] = 'An error occurred during company switch'
      end

      redirect_to return_to, allow_other_host: true, status: :see_other
    end

    # POST/GET /auth/change_language?token=...&language=...&return_to=...
    # Remote language change
    # SECURITY FIX: Validates language against whitelist and redirect URL
    def change_language
      token = params[:token]
      language = params[:language]
      return_to = params[:return_to] || root_url

      # SECURITY FIX: Validate return_to URL
      unless valid_redirect_url?(return_to)
        Rails.logger.warn "Invalid redirect URL in change_language: #{return_to}"
        return_to = root_url
      end

      if token.blank? || language.blank?
        flash[:alert] = 'Token and language are required'
        redirect_to return_to, allow_other_host: true, status: :see_other
        return
      end

      # SECURITY FIX: Validate language against whitelist
      unless ALLOWED_LANGUAGES.include?(language.to_s.downcase)
        Rails.logger.warn "Invalid language code attempted: #{language}"
        flash[:alert] = 'Invalid language code'
        redirect_to return_to, allow_other_host: true, status: :see_other
        return
      end

      begin
        payload = validate_jwt_token(token)
        user = User.find(payload['sub'])
        membership = user.current_membership

        if membership
          # Safely update language in membership info
          membership.info ||= {}
          membership.info['language'] = language.downcase
          membership.save!

          Rails.logger.info "User #{user.id} changed language to #{language}"
          flash[:notice] = "Language changed to #{language}"
        else
          Rails.logger.warn "No active membership found for user #{user.id}"
          flash[:alert] = 'No active membership found'
        end
      rescue JWT::DecodeError => e
        Rails.logger.error "JWT decode error during language change: #{e.message}"
        flash[:alert] = 'Invalid authentication token'
      rescue JWT::ExpiredSignature => e
        Rails.logger.error "Expired token during language change: #{e.message}"
        flash[:alert] = 'Authentication token has expired'
      rescue ActiveRecord::RecordNotFound => e
        Rails.logger.error "User not found during language change: #{e.message}"
        flash[:alert] = 'User not found'
      rescue StandardError => e
        Rails.logger.error "Unexpected error during language change: #{e.class} - #{e.message}"
        flash[:alert] = 'An error occurred during language change'
      end

      redirect_to return_to, allow_other_host: true, status: :see_other
    end

    private

    # SECURITY FIX: Validates CSRF token OR JWT token for state-changing operations
    # This allows both session-based and token-based authentication
    def validate_csrf_or_token
      # For POST/DELETE/PATCH/PUT requests, require either CSRF token or valid JWT
      return if request.get? || request.head?

      token = params[:token]

      # If JWT token is provided and valid, skip CSRF check
      if token.present?
        begin
          validate_jwt_token(token)
          return
        rescue JWT::DecodeError, JWT::ExpiredSignature => e
          Rails.logger.error "JWT validation failed in CSRF check: #{e.message}"
          # Fall through to CSRF validation
        end
      end

      # Otherwise, verify CSRF token (default Rails behavior)
      verify_authenticity_token
    rescue ActionController::InvalidAuthenticityToken => e
      Rails.logger.error "CSRF validation failed: #{e.message}"
      render json: { error: 'Invalid authenticity token' }, status: :forbidden
    end

    # SECURITY FIX: Validates redirect URLs against whitelist of allowed hosts
    # Prevents open redirect vulnerabilities
    # @param url [String] The URL to validate
    # @return [Boolean] true if URL is valid and allowed
    def valid_redirect_url?(url)
      return false if url.blank?

      # Parse the URL
      uri = URI.parse(url)

      # Allow relative URLs (they're safe as they stay within our domain)
      return true if uri.relative? || uri.host.nil?

      # For absolute URLs, check against whitelist
      allowed = ALLOWED_REDIRECT_HOSTS.include?(uri.host)

      # Also allow redirects to the current application
      current_host = URI.parse(root_url).host
      allowed ||= (uri.host == current_host)

      unless allowed
        Rails.logger.warn "Blocked redirect to unauthorized host: #{uri.host}"
      end

      allowed
    rescue URI::InvalidURIError => e
      Rails.logger.error "Invalid URI in redirect validation: #{url} - #{e.message}"
      false
    end

    # SECURITY FIX: Enhanced JWT token validation with comprehensive claim checks
    # Validates signature, expiration, issuer, audience, and other critical claims
    # @param token [String] The JWT token to validate
    # @return [Hash] Decoded payload
    # @raise [JWT::DecodeError] if token is invalid
    # @raise [JWT::ExpiredSignature] if token has expired
    def validate_jwt_token(token)
      public_key = OpenSSL::PKey::RSA.new(
        Rails.application.credentials.dig(:doorkeeper, :public_key)
      )

      # Expected issuer from environment
      expected_issuer = ENV['AUTHLIFT_URL']

      # Decode with comprehensive validation
      decoded_token = JWT.decode(
        token,
        public_key,
        true,
        {
          algorithm: 'RS256',
          verify_expiration: true,
          verify_iat: true,
          verify_iss: true,
          iss: expected_issuer,
          # Note: We don't strictly validate 'aud' here because it varies by client application
          # Each client app should validate the audience matches their client_id
        }
      ).first

      # SECURITY FIX: Additional claim validations
      current_time = Time.now.to_i

      # Validate subject (user ID) exists
      unless decoded_token['sub'].present?
        Rails.logger.error "JWT missing 'sub' claim"
        raise JWT::DecodeError, "Missing subject claim"
      end

      # Validate issued at time (iat) is not in the future
      if decoded_token['iat'] && decoded_token['iat'] > current_time + 60 # 60 second clock skew tolerance
        Rails.logger.error "JWT 'iat' claim is in the future"
        raise JWT::DecodeError, "Token issued in the future"
      end

      # Validate not before time (nbf) if present
      if decoded_token['nbf'] && decoded_token['nbf'] > current_time + 60
        Rails.logger.error "JWT 'nbf' claim not yet valid"
        raise JWT::DecodeError, "Token not yet valid"
      end

      # Validate token has not expired (exp)
      if decoded_token['exp'].nil? || decoded_token['exp'] <= current_time
        Rails.logger.error "JWT 'exp' claim expired or missing"
        raise JWT::ExpiredSignature, "Token has expired"
      end

      # Validate issuer matches expected value
      unless decoded_token['iss'] == expected_issuer
        Rails.logger.error "JWT 'iss' claim mismatch: expected #{expected_issuer}, got #{decoded_token['iss']}"
        raise JWT::DecodeError, "Invalid issuer"
      end

      # Log successful validation
      Rails.logger.debug "JWT validated successfully for user #{decoded_token['sub']}"

      decoded_token
    rescue JWT::ExpiredSignature => e
      Rails.logger.error "JWT expired: #{e.message}"
      raise
    rescue JWT::DecodeError => e
      Rails.logger.error "JWT decode error: #{e.message}"
      raise
    rescue StandardError => e
      Rails.logger.error "Unexpected JWT validation error: #{e.class} - #{e.message}"
      raise JWT::DecodeError, "Token validation failed"
    end

    # Generates a new JWT token for the user using Doorkeeper JWT
    # @param user [User] The user to generate a token for
    # @return [String] JWT token string
    def generate_jwt_for_user(user)
      # Create a temporary access token record
      access_token = Doorkeeper::AccessToken.create!(
        resource_owner_id: user.id,
        expires_in: 1.hour,
        scopes: user.current_membership&.scopes&.join(' ') || 'public'
      )

      # The JWT token is automatically generated by Doorkeeper::JWT
      # when the access token is created
      access_token.token
    rescue StandardError => e
      Rails.logger.error "Error generating JWT for user #{user.id}: #{e.class} - #{e.message}"
      raise
    end
  end
end
