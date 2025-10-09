# app/controllers/admin/oauth_applications_controller.rb
module Admin
  class OauthApplicationsController < Admin::BaseController
    before_action :set_oauth_application, only: [:show, :edit, :update, :destroy]

    # GET /admin/oauth_applications
    def index
      @oauth_applications = Doorkeeper::Application.includes(:owner)
                                                   .order(name: :asc)
                                                   .limit(100)  # Simple limit for now, add pagination gem later if needed

      # Optional filters
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        @oauth_applications = @oauth_applications.where('name ILIKE ? OR uid ILIKE ?', search_term, search_term)
      end

      @oauth_applications = @oauth_applications.where(trusted: true) if params[:trusted_only] == '1'
      @oauth_applications = @oauth_applications.where(partnerships_allowed: true) if params[:partnerships_only] == '1'
    end

    # GET /admin/oauth_applications/:id
    def show
      @access_tokens = Doorkeeper::AccessToken
                        .where(application_id: @oauth_application.id)
                        .order(created_at: :desc)
                        .limit(10)

      @application_domains = @oauth_application.application_domains.includes(:company).order('companies.name ASC')
      @allowed_companies = @oauth_application.companies.order(name: :asc)
    end

    # GET /admin/oauth_applications/new
    def new
      @oauth_application = Doorkeeper::Application.new
    end

    # POST /admin/oauth_applications
    def create
      @oauth_application = Doorkeeper::Application.new(oauth_application_params)

      if @oauth_application.save
        flash[:notice] = 'OAuth application was successfully created.'
        redirect_to admin_oauth_application_path(@oauth_application)
      else
        flash.now[:alert] = 'Failed to create OAuth application.'
        render :new, status: :unprocessable_entity
      end
    end

    # GET /admin/oauth_applications/:id/edit
    def edit
    end

    # PATCH/PUT /admin/oauth_applications/:id
    def update
      if @oauth_application.update(oauth_application_params)
        flash[:notice] = 'OAuth application was successfully updated.'
        redirect_to admin_oauth_application_path(@oauth_application)
      else
        flash.now[:alert] = 'Failed to update OAuth application.'
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /admin/oauth_applications/:id
    def destroy
      # SECURITY: Check if application has active tokens
      # A token is active if:
      # 1. Not revoked (revoked_at is NULL OR revoked_at > current time) AND
      # 2. Not expired (expires_in is NULL OR created_at + expires_in > current time)
      active_tokens = Doorkeeper::AccessToken
                       .where(application_id: @oauth_application.id)
                       .where('revoked_at IS NULL OR revoked_at > ?', Time.current)
                       .where('expires_in IS NULL OR created_at + (expires_in * INTERVAL \'1 second\') > ?', Time.current)
                       .count

      if active_tokens > 0
        flash[:alert] = "Cannot delete application with #{active_tokens} active tokens. Revoke all tokens first."
        redirect_to admin_oauth_application_path(@oauth_application) and return
      end

      @oauth_application.destroy
      flash[:notice] = 'OAuth application was successfully deleted.'
      redirect_to admin_oauth_applications_path
    end

    private

    def set_oauth_application
      @oauth_application = Doorkeeper::Application.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      flash[:alert] = 'OAuth application not found.'
      redirect_to admin_oauth_applications_path
    end

    def oauth_application_params
      params.require(:doorkeeper_application).permit(
        :name,
        :redirect_uri,
        :scopes,
        :confidential,
        :owner_type,
        :owner_id,
        :home,
        :partnerships_allowed,
        :application_icon,
        :trusted
      )
    end
  end
end
