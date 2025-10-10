# app/controllers/admin/base_controller.rb
module Admin
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin_access!

    layout "admin"

    private

    # SECURITY: Restrict admin area to users with admin privileges
    # Super admins have platform-level access across all companies
    # Company owners/admins have access to their own company data only
    def require_admin_access!
      # Super admins always have access
      return true if current_user.super_admin?

      # Check if user is owner or admin of at least one company
      has_admin_membership = current_user.memberships
                                         .active
                                         .where(role: %w[owner admin])
                                         .exists?

      unless has_admin_membership
        # SECURITY LOGGING: Log unauthorized access attempt
        Rails.logger.warn(
          "SECURITY: Unauthorized admin area access attempt - " \
          "User ID: #{current_user.id}, Email: #{current_user.email}, " \
          "Action: #{action_name}, Controller: #{controller_name}"
        )

        flash[:alert] = "Access denied. Admin privileges required."
        redirect_to root_path
        return false
      end

      true
    end

    # SECURITY: Check if current user can access/manage a specific company
    # Super admins can access all companies
    # Company owners/admins can only access their own company
    #
    # @param company [Company] The company to authorize access to
    # @return [Boolean] true if access is authorized, redirects and returns false otherwise
    def authorize_company_access!(company)
      # Super admins have platform-level access to all companies
      return true if current_user.super_admin?

      # Company admins/owners can only access their own company
      unless current_user.admin_for?(company)
        # SECURITY LOGGING: Log unauthorized access attempt
        Rails.logger.warn(
          "SECURITY: Unauthorized company access attempt - " \
          "User ID: #{current_user.id}, Email: #{current_user.email}, " \
          "Company ID: #{company.id}, Company Name: #{company.name}, " \
          "Action: #{action_name}, Controller: #{controller_name}"
        )

        flash[:alert] = "Access denied. You can only manage your own company."
        redirect_to root_path
        return false
      end

      true
    end

    # SECURITY: Filter companies list based on user permissions
    # Super admins see all companies
    # Company admins see only companies they have owner/admin membership in
    #
    # @param scope [ActiveRecord::Relation] The base scope to filter
    # @return [ActiveRecord::Relation] Filtered scope based on user permissions
    def filter_companies_by_access(scope)
      return scope if current_user.super_admin?

      # Get IDs of companies where user is owner or admin
      company_ids = current_user.memberships
                                .active
                                .where(role: %w[owner admin])
                                .pluck(:company_id)

      scope.where(id: company_ids)
    end
  end
end
