# app/controllers/api/v1/public_keys_controller.rb
module Api
  module V1
    class PublicKeysController < ApplicationController
      skip_before_action :verify_authenticity_token

      # GET /api/v1/.well-known/jwks.json
      # Returns the public key in JWKS (JSON Web Key Set) format
      # This is the standard format for JWT verification in most libraries
      def jwks
        render json: {
          keys: [
            {
              kty: "RSA",
              use: "sig",
              kid: "authlift-2025",
              alg: "RS256",
              n: Base64.urlsafe_encode64(public_key.n.to_s(2), padding: false),
              e: Base64.urlsafe_encode64(public_key.e.to_s(2), padding: false)
            }
          ]
        }
      rescue StandardError => e
        Rails.logger.error "JWKS generation error: #{e.message}"
        render json: { error: "Unable to generate JWKS" }, status: :internal_server_error
      end

      # GET /api/v1/public_key.pem
      # Returns the public key in PEM format
      # Useful for simple JWT verification without JWKS parsing
      def pem
        render plain: public_key.to_pem, content_type: "text/plain"
      rescue StandardError => e
        Rails.logger.error "PEM generation error: #{e.message}"
        render plain: "Unable to generate PEM", status: :internal_server_error
      end

      private

      def public_key
        @public_key ||= begin
          public_key_pem = Rails.application.credentials.dig(:doorkeeper, :public_key)

          if public_key_pem.blank?
            raise "Public key not found in credentials. Run: EDITOR=vim rails credentials:edit"
          end

          OpenSSL::PKey::RSA.new(public_key_pem)
        end
      end
    end
  end
end
