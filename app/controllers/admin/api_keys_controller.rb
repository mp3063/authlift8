# app/controllers/admin/api_keys_controller.rb
module Admin
  class ApiKeysController < Admin::BaseController
    before_action :set_api_key, only: [ :show, :edit, :update, :destroy ]
    before_action :authorize_api_key_access!, only: [ :show, :edit, :update, :destroy ]

    # GET /admin/api_keys
    def index
      @api_keys = ApiKey.includes(:company)
                        .order(created_at: :desc)
                        .limit(100)  # Simple limit for now, add pagination gem later if needed

      # SECURITY: Filter API keys based on permissions
      @api_keys = filter_api_keys_by_access(@api_keys)

      # Optional filters
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        @api_keys = @api_keys.where("name ILIKE ?", search_term)
      end

      @api_keys = @api_keys.active if params[:active_only] == "1"
    end

    # GET /admin/api_keys/:id
    def show
    end

    # GET /admin/api_keys/new
    def new
      @api_key = ApiKey.new
      # SECURITY: Filter companies to only those the user can manage
      @companies = filter_companies_by_access(Company.order(name: :asc))
    end

    # POST /admin/api_keys
    def create
      @api_key = ApiKey.new(api_key_params)

      # SECURITY: Validate that company_id belongs to a company the user manages
      unless authorize_company_for_api_key(@api_key)
        @companies = filter_companies_by_access(Company.order(name: :asc))
        flash.now[:alert] = "Access denied. You can only create API keys for your own company."
        render :new, status: :unprocessable_entity
        return
      end

      if @api_key.save
        flash[:notice] = "API Key was successfully created. Token: #{@api_key.token}"
        redirect_to admin_api_key_path(@api_key)
      else
        @companies = filter_companies_by_access(Company.order(name: :asc))
        flash.now[:alert] = "Failed to create API key."
        render :new, status: :unprocessable_entity
      end
    end

    # GET /admin/api_keys/:id/edit
    def edit
      # SECURITY: Filter companies to only those the user can manage
      @companies = filter_companies_by_access(Company.order(name: :asc))
    end

    # PATCH/PUT /admin/api_keys/:id
    def update
      # SECURITY: Validate that company_id belongs to a company the user manages
      unless authorize_company_for_api_key(@api_key)
        @companies = filter_companies_by_access(Company.order(name: :asc))
        flash.now[:alert] = "Access denied. You can only update API keys for your own company."
        render :edit, status: :unprocessable_entity
        return
      end

      if @api_key.update(api_key_params)
        flash[:notice] = "API Key was successfully updated."
        redirect_to admin_api_key_path(@api_key)
      else
        @companies = filter_companies_by_access(Company.order(name: :asc))
        flash.now[:alert] = "Failed to update API key."
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /admin/api_keys/:id
    def destroy
      @api_key.destroy
      flash[:notice] = "API Key was successfully deleted."
      redirect_to admin_api_keys_path
    end

    private

    def set_api_key
      @api_key = ApiKey.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      flash[:alert] = "API Key not found."
      redirect_to admin_api_keys_path
    end

    # SECURITY: Check if current user can access/manage this API key
    def authorize_api_key_access!
      # Super admins have platform-level access to all API keys
      return true if current_user.super_admin?

      # Check if the API key belongs to a company the user is admin/owner of
      unless current_user.admin_for?(@api_key.company)
        # SECURITY LOGGING: Log unauthorized access attempt
        Rails.logger.warn(
          "SECURITY: Unauthorized API key access attempt - " \
          "User ID: #{current_user.id}, Email: #{current_user.email}, " \
          "API Key ID: #{@api_key.id}, Company ID: #{@api_key.company_id}, " \
          "Action: #{action_name}, Controller: #{controller_name}"
        )

        flash[:alert] = "Access denied. You can only manage API keys for your own company."
        redirect_to root_path
        return false
      end

      true
    end

    # SECURITY: Validate that the API key's company is managed by the current user
    def authorize_company_for_api_key(api_key)
      return true if current_user.super_admin?
      return true if api_key.company && current_user.admin_for?(api_key.company)

      # SECURITY LOGGING: Log unauthorized company assignment attempt
      Rails.logger.warn(
        "SECURITY: Unauthorized API key company assignment attempt - " \
        "User ID: #{current_user.id}, Email: #{current_user.email}, " \
        "Attempted Company ID: #{api_key.company_id}, " \
        "Action: #{action_name}"
      )

      false
    end

    # SECURITY: Filter API keys based on user permissions
    def filter_api_keys_by_access(scope)
      return scope if current_user.super_admin?

      # Get IDs of companies where user is owner or admin
      managed_company_ids = current_user.memberships
                                        .active
                                        .where(role: %w[owner admin])
                                        .pluck(:company_id)

      scope.where(company_id: managed_company_ids)
    end

    def api_key_params
      # Parse scopes from comma-separated string to array
      permitted = params.require(:api_key).permit(:name, :company_id, :active, :expires_at, :scope_list)

      # Convert scope_list to scopes array
      if permitted[:scope_list].present?
        permitted[:scopes] = permitted[:scope_list].split(",").map(&:strip).reject(&:blank?)
        permitted.delete(:scope_list)
      end

      permitted
    end
  end
end
