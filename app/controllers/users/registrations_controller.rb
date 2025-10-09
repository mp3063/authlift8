# app/controllers/users/registrations_controller.rb
class Users::RegistrationsController < Devise::RegistrationsController
  skip_before_action :require_no_authentication, only: [:new]
  before_action :redirect_if_authenticated, only: [:new]
  before_action :configure_sign_up_params, only: [:create]
  before_action :configure_account_update_params, only: [:update]

  # GET /users/sign_up
  # def new
  #   super
  # end

  # POST /users
  # Custom registration logic:
  # - Create user
  # - Create default company for the user
  # - Create membership with role 'owner'
  def create
    build_resource(sign_up_params)

    resource.save
    yield resource if block_given?

    if resource.persisted?
      # Create default company for new user
      company = create_default_company_for(resource)

      if company.persisted?
        # Create membership with owner role
        membership = create_owner_membership(resource, company)

        if membership.persisted?
          # Set as current company
          resource.update(company: company)

          # Sign in and redirect
          if resource.active_for_authentication?
            set_flash_message! :notice, :signed_up
            sign_up(resource_name, resource)
            respond_with resource, location: after_sign_up_path_for(resource)
          else
            set_flash_message! :notice, :"signed_up_but_#{resource.inactive_message}"
            expire_data_after_sign_in!
            respond_with resource, location: after_inactive_sign_up_path_for(resource)
          end
        else
          # Membership creation failed - cleanup and show error
          company.destroy
          resource.destroy
          flash.now[:alert] = "Failed to create membership: #{membership.errors.full_messages.join(', ')}"
          build_resource(sign_up_params)
          clean_up_passwords resource
          set_minimum_password_length
          render :new, status: :unprocessable_entity
        end
      else
        # Company creation failed - cleanup and show error
        resource.destroy
        flash.now[:alert] = "Failed to create company: #{company.errors.full_messages.join(', ')}"
        build_resource(sign_up_params)
        clean_up_passwords resource
        set_minimum_password_length
        render :new, status: :unprocessable_entity
      end
    else
      clean_up_passwords resource
      set_minimum_password_length
      respond_with resource
    end
  end

  # GET /users/edit
  # def edit
  #   super
  # end

  # PUT /users
  # def update
  #   super
  # end

  # DELETE /users
  # def destroy
  #   super
  # end

  # GET /users/cancel
  # Forces the session data which is usually expired after sign
  # in to be expired now. This is useful if the user wants to
  # cancel oauth signing in/up in the middle of the process,
  # removing all OAuth session data.
  # def cancel
  #   super
  # end

  protected

  # Custom redirect after sign up
  def after_sign_up_path_for(resource)
    dashboard_path
  end

  # Custom redirect after account update
  def after_update_path_for(resource)
    dashboard_path
  end

  # Permit additional parameters for sign up (first_name, last_name)
  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :phone, :locale])
  end

  # Permit additional parameters for account update
  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name, :phone, :locale])
  end

  private

  # Redirect authenticated users away from sign up page
  def redirect_if_authenticated
    redirect_to root_path if user_signed_in?
  end

  # Create default company for new user
  # Company name format: "FirstName LastName's Company"
  def create_default_company_for(user)
    if user.first_name.present? && user.last_name.present?
      company_name = "#{user.first_name} #{user.last_name}'s Company"
    else
      company_name = "#{user.email}'s Company"
    end

    Company.create(
      name: company_name,
      email: user.email,
      locale: user.locale || 'en',
      active: true
    )
  end

  # Create owner membership for user in company
  def create_owner_membership(user, company)
    Membership.create(
      user: user,
      company: company,
      role: 'owner',
      scopes: [],
      active: true
    )
  end
end
