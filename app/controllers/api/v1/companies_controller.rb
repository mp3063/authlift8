# app/controllers/api/v1/companies_controller.rb
module Api
  module V1
    class CompaniesController < ApplicationController
      before_action :doorkeeper_authorize!
      skip_before_action :verify_authenticity_token

      # GET /api/v1/companies
      # Returns a list of companies accessible by the current user
      # Query parameters:
      #   - active: filter by active status (true/false)
      #   - page: page number for pagination
      #   - per_page: number of records per page (default: 25, max: 100)
      def index
        user = current_resource_owner

        unless user
          render json: { error: 'User not found' }, status: :not_found
          return
        end

        companies = user.companies

        # Apply filters
        companies = companies.active if params[:active] == 'true'

        # Pagination
        page = params[:page]&.to_i || 1
        per_page = [[params[:per_page]&.to_i || 25, 100].min, 1].max

        total = companies.count
        companies = companies.offset((page - 1) * per_page).limit(per_page)

        render json: {
          companies: companies.map { |c| company_data(c) },
          pagination: {
            current_page: page,
            per_page: per_page,
            total_count: total,
            total_pages: (total.to_f / per_page).ceil
          }
        }, status: :ok
      rescue StandardError => e
        Rails.logger.error "Companies index error: #{e.message}\n#{e.backtrace.join("\n")}"
        render json: { error: 'Unable to fetch companies' }, status: :internal_server_error
      end

      # GET /api/v1/companies/:id
      # Returns detailed information about a specific company
      # Includes partnerships and membership details
      def show
        user = current_resource_owner

        unless user
          render json: { error: 'User not found' }, status: :not_found
          return
        end

        # Find company that user has access to
        company = user.companies.find_by(id: params[:id])

        unless company
          render json: { error: 'Company not found or access denied' }, status: :not_found
          return
        end

        membership = user.memberships.find_by(company: company)

        render json: {
          company: company_data(company),
          membership: membership ? membership_data(membership) : nil,
          partnerships: {
            suppliers: company.suppliers.map { |s| company_data(s) },
            clients: company.clients.map { |c| company_data(c) },
            owned_count: company.owned_partnerships.active.count,
            client_count: company.client_partnerships.active.count
          },
          api_keys_count: company.api_keys.where(active: true).count,
          customer_groups_count: company.customer_groups.where(enabled: true).count,
          oauth_applications_count: company.oauth_applications.count
        }, status: :ok
      rescue StandardError => e
        Rails.logger.error "Company show error: #{e.message}\n#{e.backtrace.join("\n")}"
        render json: { error: 'Unable to fetch company details' }, status: :internal_server_error
      end

      private

      # Get the current authenticated user from the Doorkeeper token
      def current_resource_owner
        return @current_resource_owner if defined?(@current_resource_owner)

        @current_resource_owner = if doorkeeper_token
          User.find_by(id: doorkeeper_token.resource_owner_id)
        end
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
          },
          created_at: company.created_at,
          updated_at: company.updated_at
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
