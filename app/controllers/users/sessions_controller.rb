# app/controllers/users/sessions_controller.rb
class Users::SessionsController < Devise::SessionsController
  skip_before_action :require_no_authentication, only: [ :new ]
  before_action :redirect_if_authenticated, only: [ :new ]
  # before_action :configure_sign_in_params, only: [:create]

  # GET /users/sign_in
  # def new
  #   super
  # end

  # POST /users/sign_in
  def create
    super do |resource|
      # Track sign-in with Devise trackable fields (already handled by Devise)
      # Additional custom tracking can be added here if needed
      Rails.logger.info "User #{resource.id} (#{resource.email}) signed in successfully"
    end
  end

  # DELETE /users/sign_out
  # def destroy
  #   super
  # end

  protected

  # Custom redirect path after sign in
  # Redirects to dashboard instead of root
  def after_sign_in_path_for(resource)
    stored_location_for(resource) || dashboard_path
  end

  # Custom redirect path after sign out
  def after_sign_out_path_for(resource_or_scope)
    new_user_session_path
  end

  private

  # Redirect authenticated users away from sign in page
  def redirect_if_authenticated
    redirect_to root_path if user_signed_in?
  end

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_in_params
  #   devise_parameter_sanitizer.permit(:sign_in, keys: [:attribute])
  # end
end
