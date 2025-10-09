# app/controllers/companies_controller.rb
class CompaniesController < ApplicationController
  before_action :authenticate_user!

  # POST /switch_company/:id
  # Switch user's current company context
  # Updates user.company_id to switch company and redirects back to dashboard
  def switch
    @company = Company.find(params[:id])

    # SECURITY: Verify user has active membership in the target company
    membership = current_user.memberships.active.find_by(company: @company)

    unless membership
      flash[:alert] = "You don't have access to #{@company.name}"
      redirect_to dashboard_path and return
    end

    # Update current company context
    if current_user.update(company: @company)
      flash[:notice] = "Switched to #{@company.name}"
    else
      flash[:alert] = "Failed to switch company"
    end

    # Redirect to return_to parameter if provided, otherwise dashboard
    redirect_to params[:return_to] || dashboard_path
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "Company not found"
    redirect_to dashboard_path
  end
end
