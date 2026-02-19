# app/controllers/admin/users_controller.rb
module Admin
  class UsersController < Admin::BaseController
    before_action :set_user, only: [ :show, :edit, :update, :destroy, :add_to_company, :unlock ]
    before_action :authorize_user_access!, only: [ :show, :edit, :update, :destroy, :add_to_company, :unlock ]

    # GET /admin/users
    def index
      @users = User.includes(:company, :memberships)
                   .order(created_at: :desc)
                   .limit(100)  # Simple limit for now, add pagination gem later if needed

      # SECURITY: Filter users based on permissions
      @users = filter_users_by_access(@users)

      # Optional filters
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        @users = @users.where(
          "email ILIKE ? OR first_name ILIKE ? OR last_name ILIKE ?",
          search_term, search_term, search_term
        )
      end

      @users = @users.super_admins if params[:super_admins_only] == "1"
    end

    # GET /admin/users/:id
    def show
      @memberships = @user.memberships.includes(:company).order("companies.name ASC")
      @oauth_tokens = @user.oauth_access_tokens.order(created_at: :desc).limit(10)
      @available_companies = filter_companies_by_access(
        Company.where.not(id: @user.memberships.pluck(:company_id)).order(:name)
      )
    end

    # GET /admin/users/:id/edit
    def edit
    end

    # PATCH/PUT /admin/users/:id
    def update
      respond_to do |format|
        if @user.update(user_params)
          format.html do
            flash[:notice] = "User was successfully updated."
            redirect_to admin_user_path(@user), status: :see_other
          end
          format.turbo_stream do
            flash[:notice] = "User was successfully updated."
            redirect_to admin_user_path(@user), status: :see_other
          end
        else
          format.html do
            flash.now[:alert] = "Failed to update user."
            render :edit, status: :unprocessable_entity
          end
          format.turbo_stream do
            flash.now[:alert] = "Failed to update user."
            render :edit, status: :unprocessable_entity
          end
        end
      end
    end

    # POST /admin/users/:id/add_to_company
    def add_to_company
      company = Company.find(params[:company_id])
      authorize_company_access!(company)

      membership = Membership.new(
        user: @user,
        company: company,
        role: params[:role] || "member",
        active: true
      )

      if membership.save
        redirect_to admin_user_path(@user), notice: "#{@user.full_name} added to #{company.name}."
      else
        redirect_to admin_user_path(@user), alert: membership.errors.full_messages.join(", ")
      end
    end

    # PATCH /admin/users/:id/unlock
    def unlock
      @user.unlock_access!
      Rails.logger.info "SECURITY: Admin #{current_user.id} (#{current_user.email}) unlocked account #{@user.id} (#{@user.email})"
      redirect_to admin_user_path(@user), notice: "Account unlocked successfully."
    end

    # DELETE /admin/users/:id
    def destroy
      # SECURITY: Prevent self-deletion
      if @user == current_user
        flash[:alert] = "You cannot delete your own account."
        redirect_to admin_users_path and return
      end

      # SECURITY: Prevent deletion if user is the only owner of any company
      sole_owner_companies = @user.memberships.owners.select do |membership|
        membership.company.memberships.owners.count == 1
      end

      if sole_owner_companies.any?
        company_names = sole_owner_companies.map { |m| m.company.name }.join(", ")
        flash[:alert] = "Cannot delete user: sole owner of companies: #{company_names}"
        redirect_to admin_user_path(@user) and return
      end

      @user.destroy
      flash[:notice] = "User was successfully deleted."
      redirect_to admin_users_path
    end

    private

    def set_user
      @user = User.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      flash[:alert] = "User not found."
      redirect_to admin_users_path
    end

    # SECURITY: Check if current user can access/manage this user
    def authorize_user_access!
      # Super admins have platform-level access to all users
      return true if current_user.super_admin?

      # Company admins can only access users in companies they manage
      managed_company_ids = current_user.memberships
                                        .active
                                        .where(role: %w[owner admin])
                                        .pluck(:company_id)

      # Check if the target user has any membership in companies managed by current user
      user_in_managed_company = @user.memberships
                                     .active
                                     .where(company_id: managed_company_ids)
                                     .exists?

      unless user_in_managed_company
        # SECURITY LOGGING: Log unauthorized access attempt
        Rails.logger.warn(
          "SECURITY: Unauthorized user access attempt - " \
          "Current User ID: #{current_user.id}, Email: #{current_user.email}, " \
          "Target User ID: #{@user.id}, Target Email: #{@user.email}, " \
          "Action: #{action_name}, Controller: #{controller_name}"
        )

        flash[:alert] = "Access denied. You can only manage users in your company."
        redirect_to root_path
        return false
      end

      true
    end

    # SECURITY: Filter users list based on user permissions
    def filter_users_by_access(scope)
      return scope if current_user.super_admin?

      # Get IDs of companies where user is owner or admin
      managed_company_ids = current_user.memberships
                                        .active
                                        .where(role: %w[owner admin])
                                        .pluck(:company_id)

      # Filter to only show users who have memberships in managed companies
      scope.joins(:memberships)
           .where(memberships: { company_id: managed_company_ids })
           .distinct
    end

    def user_params
      # SECURITY: Only super admins can set super_admin flag
      allowed_params = [
        :email,
        :first_name,
        :last_name,
        :phone,
        :locale,
        :scopes,
        :company_id
      ]

      allowed_params << :super_admin if current_user.super_admin?

      params.require(:user).permit(*allowed_params)
    end
  end
end
