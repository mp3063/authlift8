# app/controllers/admin/dashboard_controller.rb
module Admin
  class DashboardController < Admin::BaseController
    # GET /admin
    # GET /admin/dashboard
    def index
      # Stats for dashboard
      @total_users = User.count
      @total_companies = Company.count
      @total_oauth_apps = Doorkeeper::Application.count
      @active_tokens = Doorkeeper::AccessToken
                        .where('revoked_at IS NULL OR revoked_at > ?', Time.current)
                        .where('expires_in IS NULL OR created_at + (expires_in * INTERVAL \'1 second\') > ?', Time.current)
                        .count

      # Recent activity
      @recent_users = User.order(created_at: :desc).limit(10)
      @recent_companies = Company.order(created_at: :desc).limit(10)
      @recent_tokens = Doorkeeper::AccessToken
                        .order(created_at: :desc)
                        .limit(10)
    end
  end
end
