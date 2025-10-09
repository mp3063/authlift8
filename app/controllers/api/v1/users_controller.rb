# app/controllers/api/v1/users_controller.rb
module Api
  module V1
    class UsersController < ApplicationController
      before_action :doorkeeper_authorize!
      skip_before_action :verify_authenticity_token

      # GET /api/v1/users/profile
      # Returns the current authenticated user's profile with company and membership info
      def profile
        user = current_resource_owner

        if user
          render json: user_profile_response(user), status: :ok
        else
          render json: { error: 'User not found' }, status: :not_found
        end
      rescue StandardError => e
        Rails.logger.error "Profile fetch error: #{e.message}\n#{e.backtrace.join("\n")}"
        render json: { error: 'Unable to fetch profile' }, status: :internal_server_error
      end

      # GET /api/v1/users/company_info/:company_id
      # Returns company information including partnerships for a specific company
      # If no company_id provided, uses the user's current company
      # SECURITY: Only returns data for companies with ACTIVE memberships
      def company_info
        user = current_resource_owner

        unless user
          render json: { error: 'User not found' }, status: :not_found
          return
        end

        # Find active membership for the requested company
        membership = if params[:company_id].present?
          # IDOR FIX: Verify active membership before granting access
          user.memberships.active.find_by(company_id: params[:company_id])
        else
          # Use current company membership if no ID provided
          user.current_membership
        end

        # Log security-relevant access attempts
        if params[:company_id].present? && membership.nil?
          Rails.logger.warn "SECURITY: User #{user.id} attempted to access company #{params[:company_id]} without active membership - IP: #{request.remote_ip}"
        end

        unless membership
          render json: { error: 'Company not found or access denied' }, status: :forbidden
          return
        end

        # Verify membership is active before returning data
        unless membership.active
          Rails.logger.warn "SECURITY: User #{user.id} attempted to access company #{membership.company_id} with inactive membership - IP: #{request.remote_ip}"
          render json: { error: 'Access denied - membership inactive' }, status: :forbidden
          return
        end

        company = membership.company

        unless company
          render json: { error: 'Company not found' }, status: :not_found
          return
        end

        render json: company_info_response(user, company, membership), status: :ok
      rescue StandardError => e
        Rails.logger.error "Company info fetch error: #{e.message}\n#{e.backtrace.join("\n")}"
        render json: { error: 'Unable to fetch company information' }, status: :internal_server_error
      end

      private

      # Get the current authenticated user from the Doorkeeper token
      def current_resource_owner
        return @current_resource_owner if defined?(@current_resource_owner)

        @current_resource_owner = if doorkeeper_token
          User.find_by(id: doorkeeper_token.resource_owner_id)
        end
      end

      # Build user profile response hash
      # SECURITY: Only returns companies with active memberships
      def user_profile_response(user)
        company = user.current_company
        membership = user.current_membership

        # SECURITY FIX: Only include companies with active memberships
        active_companies = user.memberships.active.includes(:company).map(&:company).compact

        {
          id: user.id,
          email: user.email,
          first_name: user.first_name,
          last_name: user.last_name,
          full_name: user.full_name,
          phone: user.phone,
          locale: user.locale,
          admin: user.admin,
          company: company ? company_data(company) : nil,
          membership: membership ? membership_data(membership) : nil,
          all_companies: active_companies.map { |c| company_data(c) }
        }
      end

      # Build company info response with partnerships
      # SECURITY: Only called after active membership verification
      def company_info_response(user, company, membership)
        {
          company: company_data(company),
          membership: membership ? membership_data(membership) : nil,
          suppliers: company.suppliers.map { |s| company_data(s) },
          clients: company.clients.map { |c| company_data(c) },
          partnerships: {
            as_owner: company.owned_partnerships.active.count,
            as_client: company.client_partnerships.active.count
          }
        }
      end

      # Serialize company data
      def company_data(company)
        {
          id: company.id,
          code: company.code,
          name: company.name,
          logo_code: company.logo_code,
          vat_id: company.vat_id,
          business_id: company.business_id,
          email: company.email,
          phone: company.phone,
          website: company.website,
          locale: company.locale,
          active: company.active,
          info: company.info,
          address: {
            line1: company.address_line1,
            line2: company.address_line2,
            city: company.city,
            state: company.state,
            postal_code: company.postal_code,
            country: company.country
          }
        }
      end

      # Serialize membership data
      def membership_data(membership)
        {
          id: membership.id,
          role: membership.role,
          scopes: membership.scopes || [],
          active: membership.active,
          info: membership.info,
          created_at: membership.created_at,
          updated_at: membership.updated_at
        }
      end
    end
  end
end
