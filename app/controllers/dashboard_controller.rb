# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  before_action :authenticate_user!

  # GET /dashboard
  # Display user dashboard with company info, memberships, and recent activity
  def show
    @user = current_user
    @current_company = current_user.current_company
    @current_membership = current_user.current_membership

    # All companies user belongs to (with active memberships)
    @user_companies = current_user.memberships
                                  .active
                                  .includes(:company)
                                  .order("companies.name ASC")
                                  .map(&:company)

    # OAuth applications available for current company
    if @current_company
      # Applications owned by this company
      @owned_applications = @current_company.oauth_applications.order(name: :asc)

      # Applications this company has access to (HABTM)
      @available_applications = @current_company.allowed_applications.order(name: :asc)

      # Partnership information
      @suppliers = @current_company.suppliers.active.order(name: :asc)
      @clients = @current_company.clients.active.order(name: :asc)

      # Recent OAuth access tokens for this user
      @recent_tokens = current_user.oauth_access_tokens
                                   .where.not(revoked_at: nil)
                                   .or(current_user.oauth_access_tokens.where(revoked_at: nil))
                                   .order(created_at: :desc)
                                   .limit(5)
    else
      @owned_applications = []
      @available_applications = []
      @suppliers = []
      @clients = []
      @recent_tokens = []
    end
  end

  # GET / (root path)
  def index
    show
    render :show
  end
end
