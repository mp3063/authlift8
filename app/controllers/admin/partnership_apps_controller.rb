# app/controllers/admin/partnership_apps_controller.rb
module Admin
  class PartnershipAppsController < Admin::BaseController
    before_action :set_company
    before_action -> { authorize_company_access!(@company) }
    before_action :set_partnership

    # POST /admin/companies/:company_id/partnerships/:partnership_id/partnership_apps
    def create
      @partnership_app = @partnership.partnership_apps.build(
        oauth_application_id: params[:oauth_application_id]
      )

      if @partnership_app.save
        redirect_to admin_company_partnership_path(@company, @partnership),
                    notice: "Application was added to this partnership."
      else
        redirect_to admin_company_partnership_path(@company, @partnership),
                    alert: "Could not add application: #{@partnership_app.errors.full_messages.join(', ')}"
      end
    end

    # DELETE /admin/companies/:company_id/partnerships/:partnership_id/partnership_apps/:id
    def destroy
      @partnership_app = @partnership.partnership_apps.find(params[:id])
      @partnership_app.destroy!
      redirect_to admin_company_partnership_path(@company, @partnership),
                  notice: "Application was removed from this partnership."
    end

    private

    def set_company
      @company = Company.find(params[:company_id])
    end

    def set_partnership
      @partnership = Partnership.where(
        "partner_owner_id = :company_id OR partner_client_id = :company_id",
        company_id: @company.id
      ).find(params[:partnership_id])
    end
  end
end
