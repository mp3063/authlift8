# app/controllers/users/omniauth_callbacks_controller.rb
class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token, only: [:google_oauth2, :facebook, :github, :twitter]

  # GET /users/auth/google_oauth2/callback
  def google_oauth2
    handle_omniauth('Google')
  end

  # GET /users/auth/facebook/callback
  def facebook
    handle_omniauth('Facebook')
  end

  # GET /users/auth/github/callback
  def github
    handle_omniauth('GitHub')
  end

  # GET /users/auth/twitter/callback
  def twitter
    handle_omniauth('Twitter')
  end

  # GET/POST /users/auth/failure
  def failure
    provider = params[:strategy]&.humanize || 'OAuth provider'
    error_message = params[:message]&.humanize || 'authentication failed'

    flash[:alert] = "#{provider} authentication failed: #{error_message}"
    redirect_to new_user_session_path
  end

  private

  # Common handler for all OAuth callbacks
  def handle_omniauth(provider_name)
    @user = User.from_omniauth(request.env['omniauth.auth'])

    if @user.persisted?
      # Sign in the user
      sign_in_and_redirect @user, event: :authentication
      set_flash_message(:notice, :success, kind: provider_name) if is_navigational_format?
    else
      # User creation failed
      session['devise.oauth_data'] = request.env['omniauth.auth'].except('extra')
      flash[:alert] = "Failed to authenticate with #{provider_name}. Please try again or use email/password."
      redirect_to new_user_registration_path
    end
  rescue StandardError => e
    Rails.logger.error "OmniAuth error for #{provider_name}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    flash[:alert] = "An error occurred during #{provider_name} authentication. Please try again."
    redirect_to new_user_session_path
  end
end
