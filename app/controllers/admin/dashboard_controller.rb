# app/controllers/admin/dashboard_controller.rb
module Admin
  class DashboardController < Admin::BaseController
    # GET /admin
    # GET /admin/dashboard
    def index
      if current_user.super_admin?
        # SUPER ADMIN: Platform-wide statistics
        @total_users = User.count
        @total_companies = Company.count
        @total_oauth_apps = Doorkeeper::Application.count
        @active_tokens = Doorkeeper::AccessToken
                          .where("revoked_at IS NULL OR revoked_at > ?", Time.current)
                          .where("expires_in IS NULL OR created_at + (expires_in * INTERVAL '1 second') > ?", Time.current)
                          .count

        # Recent activity
        @recent_users = User.order(created_at: :desc).limit(10)
        @recent_companies = Company.order(created_at: :desc).limit(10)
        @recent_tokens = Doorkeeper::AccessToken
                          .order(created_at: :desc)
                          .limit(10)
      else
        # COMPANY ADMIN: Company-specific statistics only
        @managed_company_ids = current_user.memberships
                                           .active
                                           .where(role: %w[owner admin])
                                           .pluck(:company_id)

        # Stats scoped to managed companies
        @total_users = Membership.where(company_id: @managed_company_ids).distinct.count(:user_id)
        @total_companies = @managed_company_ids.count
        @total_oauth_apps = Doorkeeper::Application.where(owner_type: "Company", owner_id: @managed_company_ids).count
        @active_tokens = Doorkeeper::AccessToken
                          .joins("INNER JOIN oauth_applications ON oauth_applications.id = oauth_access_tokens.application_id")
                          .where("oauth_applications.owner_type = 'Company' AND oauth_applications.owner_id IN (?)", @managed_company_ids)
                          .where("oauth_access_tokens.revoked_at IS NULL OR oauth_access_tokens.revoked_at > ?", Time.current)
                          .where("oauth_access_tokens.expires_in IS NULL OR oauth_access_tokens.created_at + (oauth_access_tokens.expires_in * INTERVAL '1 second') > ?", Time.current)
                          .count

        # Recent activity scoped to managed companies
        @recent_users = User.joins(:memberships)
                           .where(memberships: { company_id: @managed_company_ids })
                           .distinct
                           .order(created_at: :desc)
                           .limit(10)
        @recent_companies = Company.where(id: @managed_company_ids)
                                   .order(created_at: :desc)
                                   .limit(10)
        @recent_tokens = Doorkeeper::AccessToken
                          .joins("INNER JOIN oauth_applications ON oauth_applications.id = oauth_access_tokens.application_id")
                          .where("oauth_applications.owner_type = 'Company' AND oauth_applications.owner_id IN (?)", @managed_company_ids)
                          .order(created_at: :desc)
                          .limit(10)
      end
    end
  end
end
