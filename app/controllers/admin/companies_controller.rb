# app/controllers/admin/companies_controller.rb
module Admin
  class CompaniesController < Admin::BaseController
    before_action :set_company, only: [ :show, :edit, :update, :destroy ]

    # GET /admin/companies
    def index
      @companies = Company.includes(:users, :memberships)
                          .order(name: :asc)
                          .limit(100)  # Simple limit for now, add pagination gem later if needed

      # Optional filters
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        @companies = @companies.where(
          "name ILIKE ? OR code ILIKE ? OR email ILIKE ?",
          search_term, search_term, search_term
        )
      end

      @companies = @companies.active if params[:active_only] == "1"
    end

    # GET /admin/companies/:id
    def show
      @memberships = @company.memberships.includes(:user).order("users.first_name ASC, users.last_name ASC")
      @oauth_applications = @company.oauth_applications.order(name: :asc)
      @api_keys = @company.api_keys.order(created_at: :desc).limit(10)

      # Partnership information
      @owned_partnerships = @company.owned_partnerships.includes(:partner_client).order("companies.name ASC")
      @client_partnerships = @company.client_partnerships.includes(:partner_owner).order("companies.name ASC")
    end

    # GET /admin/companies/new
    def new
      @company = Company.new
    end

    # POST /admin/companies
    def create
      @company = Company.new(company_params)

      if @company.save
        flash[:notice] = "Company was successfully created."
        redirect_to admin_company_path(@company)
      else
        flash.now[:alert] = "Failed to create company."
        render :new, status: :unprocessable_entity
      end
    end

    # GET /admin/companies/:id/edit
    def edit
    end

    # PATCH/PUT /admin/companies/:id
    def update
      if @company.update(company_params)
        flash[:notice] = "Company was successfully updated."
        redirect_to admin_company_path(@company)
      else
        flash.now[:alert] = "Failed to update company."
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /admin/companies/:id
    def destroy
      # SECURITY: Check if company has any active memberships
      if @company.memberships.active.exists?
        flash[:alert] = "Cannot delete company with active members. Remove all members first."
        redirect_to admin_company_path(@company) and return
      end

      # SECURITY: Check if company has any OAuth applications
      if @company.oauth_applications.exists?
        flash[:alert] = "Cannot delete company with OAuth applications. Delete applications first."
        redirect_to admin_company_path(@company) and return
      end

      # SECURITY: Check if company has any partnerships
      if @company.owned_partnerships.exists? || @company.client_partnerships.exists?
        flash[:alert] = "Cannot delete company with partnerships. Remove partnerships first."
        redirect_to admin_company_path(@company) and return
      end

      @company.destroy
      flash[:notice] = "Company was successfully deleted."
      redirect_to admin_companies_path
    end

    private

    def set_company
      @company = Company.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      flash[:alert] = "Company not found."
      redirect_to admin_companies_path
    end

    def company_params
      params.require(:company).permit(
        :code,
        :name,
        :vat_id,
        :business_id,
        :address_line1,
        :address_line2,
        :city,
        :state,
        :postal_code,
        :country,
        :email,
        :phone,
        :website,
        :logo_code,
        :locale,
        :active,
        info: {},
        settings: {}
      )
    end
  end
end
