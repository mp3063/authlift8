# app/controllers/admin/users_controller.rb
module Admin
  class UsersController < Admin::BaseController
    before_action :set_user, only: [ :show, :edit, :update, :destroy ]

    # GET /admin/users
    def index
      @users = User.includes(:company, :memberships)
                   .order(created_at: :desc)
                   .limit(100)  # Simple limit for now, add pagination gem later if needed

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
    end

    # GET /admin/users/:id/edit
    def edit
    end

    # PATCH/PUT /admin/users/:id
    def update
      if @user.update(user_params)
        flash[:notice] = "User was successfully updated."
        redirect_to admin_user_path(@user)
      else
        flash.now[:alert] = "Failed to update user."
        render :edit, status: :unprocessable_entity
      end
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

    def user_params
      params.require(:user).permit(
        :email,
        :first_name,
        :last_name,
        :phone,
        :locale,
        :super_admin,
        :scopes,
        :company_id
      )
    end
  end
end
