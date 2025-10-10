# app/controllers/admin/partnerships_controller.rb
module Admin
  class PartnershipsController < Admin::BaseController
    before_action :set_company
    before_action -> { authorize_company_access!(@company) }
    before_action :set_partnership, only: [ :show, :edit, :update, :destroy ]

    # GET /admin/companies/:company_id/partnerships
    def index
      @owned_partnerships = @company.owned_partnerships
                                    .includes(:partner_client)
                                    .order("companies.name ASC")
      @client_partnerships = @company.client_partnerships
                                     .includes(:partner_owner)
                                     .order("companies.name ASC")
    end

    # GET /admin/companies/:company_id/partnerships/:id
    def show
    end

    # GET /admin/companies/:company_id/partnerships/new
    def new
      @partnership = Partnership.new(partner_owner: @company)
      @available_companies = Company.where.not(id: @company.id)
                                    .where.not(id: @company.owned_partnerships.pluck(:partner_client_id))
                                    .where.not(id: @company.client_partnerships.pluck(:partner_owner_id))
                                    .order(:name)
    end

    # GET /admin/companies/:company_id/partnerships/:id/edit
    def edit
    end

    # POST /admin/companies/:company_id/partnerships
    def create
      @partnership = Partnership.new(partnership_params)
      @partnership.partner_owner = @company

      if @partnership.save
        redirect_to admin_company_partnerships_path(@company),
                    notice: "Partnership was successfully created."
      else
        @available_companies = Company.where.not(id: @company.id)
                                      .where.not(id: @company.owned_partnerships.pluck(:partner_client_id))
                                      .where.not(id: @company.client_partnerships.pluck(:partner_owner_id))
                                      .order(:name)
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /admin/companies/:company_id/partnerships/:id
    def update
      if @partnership.update(partnership_params)
        redirect_to admin_company_partnerships_path(@company),
                    notice: "Partnership was successfully updated.",
                    status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /admin/companies/:company_id/partnerships/:id
    def destroy
      @partnership.destroy!
      redirect_to admin_company_partnerships_path(@company),
                  notice: "Partnership was successfully deleted."
    end

    private

    def set_company
      @company = Company.find(params[:company_id])
    end

    def set_partnership
      @partnership = Partnership.where(
        "partner_owner_id = :company_id OR partner_client_id = :company_id",
        company_id: @company.id
      ).find(params[:id])
    end

    def partnership_params
      params.require(:partnership).permit(:partner_client_id, :active, :info, :settings)
    end
  end
end
