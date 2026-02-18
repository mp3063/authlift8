# app/controllers/api/v1/auth_controller.rb
module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :verify_authenticity_token

      # POST /api/v1/auth/api_key
      # Authenticates an API key and returns a JWT token for M2M communication
      def api_key
        token = extract_token
        unless token
          render json: { error: "Missing API key" }, status: :unauthorized
          return
        end

        key = ApiKey.find_by(token: token)
        unless key
          log_failed_attempt(token, "not found")
          render json: { error: "Invalid API key" }, status: :unauthorized
          return
        end

        unless key.valid_key?
          log_failed_attempt(token, key.expired? ? "expired" : "inactive")
          render json: { error: "API key is inactive or expired" }, status: :unauthorized
          return
        end

        if params[:scope].present? && !key.has_scope?(params[:scope])
          log_failed_attempt(token, "scope '#{params[:scope]}' not authorized")
          render json: { error: "Scope not authorized" }, status: :forbidden
          return
        end

        key.touch_last_used!
        jwt = generate_jwt_for_api_key(key)
        scopes = params[:scope].present? ? [ params[:scope] ] : key.scopes

        render json: {
          token: jwt,
          expires_in: 3600,
          token_type: "Bearer",
          company_id: key.company_id,
          scopes: scopes
        }, status: :ok
      rescue StandardError => e
        Rails.logger.error "API key auth error: #{e.class} - #{e.message}"
        render json: { error: "Authentication failed" }, status: :internal_server_error
      end

      private

      def extract_token
        # Accept via Authorization: Bearer <token> header or api_key body param
        auth_header = request.headers["Authorization"]
        if auth_header&.start_with?("Bearer ")
          auth_header.split(" ", 2).last
        else
          params[:api_key]
        end
      end

      def generate_jwt_for_api_key(api_key)
        private_key = OpenSSL::PKey::RSA.new(
          Rails.application.credentials.dig(:doorkeeper, :private_key)
        )

        payload = {
          iss: ENV["AUTHLIFT_URL"],
          sub: "api_key:#{api_key.id}",
          company_id: api_key.company_id,
          scopes: params[:scope].present? ? [ params[:scope] ] : api_key.scopes,
          iat: Time.now.to_i,
          exp: 1.hour.from_now.to_i,
          jti: SecureRandom.hex(32),
          type: "api_key"
        }

        JWT.encode(payload, private_key, "RS256")
      end

      def log_failed_attempt(token, reason)
        truncated = token.to_s[0, 8]
        Rails.logger.warn "SECURITY: API key auth failed - token=#{truncated}... reason=#{reason} ip=#{request.remote_ip}"
      end
    end
  end
end
