# app/controllers/admin/base_controller.rb
module Admin
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_super_admin!

    layout "admin"

    private

    # SECURITY: Restrict admin area to super_admin users only
    # Super admins have platform-level access across all companies
    def require_super_admin!
      unless current_user.super_admin?
        flash[:alert] = "Access denied. Super admin privileges required."
        redirect_to root_path
      end
    end
  end
end
