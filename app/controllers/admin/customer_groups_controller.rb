# app/controllers/admin/customer_groups_controller.rb
module Admin
  class CustomerGroupsController < Admin::BaseController
    before_action :set_company
    before_action -> { authorize_company_access!(@company) }
    before_action :set_customer_group, only: [ :show, :edit, :update, :destroy ]

    # GET /admin/companies/:company_id/customer_groups
    def index
      @customer_groups = @company.customer_groups.order(name: :asc)
      @customer_groups = @customer_groups.where(group_type: params[:group_type]) if params[:group_type].present?
      @customer_groups = @customer_groups.where(enabled: params[:enabled] == "1") if params[:enabled].present?
    end

    # GET /admin/companies/:company_id/customer_groups/:id
    def show
    end

    # GET /admin/companies/:company_id/customer_groups/new
    def new
      @customer_group = @company.customer_groups.build(enabled: true)
    end

    # GET /admin/companies/:company_id/customer_groups/:id/edit
    def edit
    end

    # POST /admin/companies/:company_id/customer_groups
    def create
      @customer_group = @company.customer_groups.build(customer_group_params)

      if @customer_group.save
        redirect_to admin_company_customer_groups_path(@company),
                    notice: "Customer group was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /admin/companies/:company_id/customer_groups/:id
    def update
      if @customer_group.update(customer_group_params)
        redirect_to admin_company_customer_group_path(@company, @customer_group),
                    notice: "Customer group was successfully updated.",
                    status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /admin/companies/:company_id/customer_groups/:id
    def destroy
      @customer_group.destroy!
      redirect_to admin_company_customer_groups_path(@company),
                  notice: "Customer group was successfully deleted."
    end

    private

    def set_company
      @company = Company.find(params[:company_id])
    end

    def set_customer_group
      @customer_group = @company.customer_groups.find(params[:id])
    end

    def customer_group_params
      permitted = params.require(:customer_group).permit(
        :name, :group_type, :enabled,
        :price_multiplier, :discount_percentage,
        :allowed_product_ids, :excluded_product_ids
      )

      build_jsonb_fields(permitted)
    end

    def build_jsonb_fields(permitted)
      pricing_rules = {}
      pricing_rules["price_multiplier"] = permitted.delete(:price_multiplier).to_f if permitted[:price_multiplier].present?
      pricing_rules["discount_percentage"] = permitted.delete(:discount_percentage).to_f if permitted[:discount_percentage].present?
      permitted[:pricing_rules] = pricing_rules if pricing_rules.present?

      restriction_rules = {}
      if permitted[:allowed_product_ids].present?
        restriction_rules["allowed_product_ids"] = parse_id_list(permitted.delete(:allowed_product_ids))
      else
        permitted.delete(:allowed_product_ids)
      end
      if permitted[:excluded_product_ids].present?
        restriction_rules["excluded_product_ids"] = parse_id_list(permitted.delete(:excluded_product_ids))
      else
        permitted.delete(:excluded_product_ids)
      end
      permitted[:product_restriction_rules] = restriction_rules if restriction_rules.present?

      permitted
    end

    def parse_id_list(str)
      return [] if str.blank?

      str.split(",").map(&:strip).reject(&:blank?)
    end
  end
end
