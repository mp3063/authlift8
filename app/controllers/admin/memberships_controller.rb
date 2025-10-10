# app/controllers/admin/memberships_controller.rb
module Admin
  class MembershipsController < Admin::BaseController
    before_action :set_company
    before_action -> { authorize_company_access!(@company) }
    before_action :set_membership, only: [ :show, :edit, :update, :destroy ]

    # GET /admin/companies/:company_id/memberships
    def index
      @memberships = @company.memberships
                             .includes(:user)
                             .order("users.first_name ASC, users.last_name ASC")
    end

    # GET /admin/companies/:company_id/memberships/:id
    def show
    end

    # GET /admin/companies/:company_id/memberships/new
    def new
      @membership = @company.memberships.build
      @available_users = User.where.not(id: @company.memberships.pluck(:user_id))
                             .order(:email)
    end

    # GET /admin/companies/:company_id/memberships/:id/edit
    def edit
    end

    # POST /admin/companies/:company_id/memberships
    def create
      @membership = @company.memberships.build(membership_params)

      if @membership.save
        redirect_to admin_company_memberships_path(@company),
                    notice: "Membership was successfully created."
      else
        @available_users = User.where.not(id: @company.memberships.pluck(:user_id))
                               .order(:email)
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /admin/companies/:company_id/memberships/:id
    def update
      if @membership.update(membership_params)
        redirect_to admin_company_memberships_path(@company),
                    notice: "Membership was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /admin/companies/:company_id/memberships/:id
    def destroy
      @membership.destroy!
      redirect_to admin_company_memberships_path(@company),
                  notice: "Membership was successfully deleted."
    end

    private

    def set_company
      @company = Company.find(params[:company_id])
    end

    def set_membership
      @membership = @company.memberships.find(params[:id])
    end

    def membership_params
      params.require(:membership).permit(:user_id, :role, :active, scopes: [])
    end
  end
end
