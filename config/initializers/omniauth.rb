# frozen_string_literal: true

Rails.application.config.middleware.use OmniAuth::Builder do
  # Google OAuth2
  provider :google_oauth2,
           ENV['GOOGLE_CLIENT_ID'],
           ENV['GOOGLE_CLIENT_SECRET'],
           {
             scope: 'email,profile',
             prompt: 'select_account',
             image_aspect_ratio: 'square',
             image_size: 50
           }

  # Note: Install additional gems as needed:
  # - omniauth-facebook for Facebook OAuth
  # - omniauth-github for GitHub OAuth
  # - omniauth-twitter for Twitter OAuth

  # Facebook OAuth2 (commented out - install omniauth-facebook gem first)
  # provider :facebook,
  #          ENV['FACEBOOK_APP_ID'],
  #          ENV['FACEBOOK_APP_SECRET'],
  #          {
  #            scope: 'email,public_profile',
  #            info_fields: 'email,first_name,last_name,name'
  #          }

  # GitHub OAuth2 (commented out - install omniauth-github gem first)
  # provider :github,
  #          ENV['GITHUB_CLIENT_ID'],
  #          ENV['GITHUB_CLIENT_SECRET'],
  #          {
  #            scope: 'user:email'
  #          }

  # Twitter OAuth2 (commented out - install omniauth-twitter gem first)
  # provider :twitter,
  #          ENV['TWITTER_API_KEY'],
  #          ENV['TWITTER_API_SECRET'],
  #          {
  #            scope: 'users.read,tweet.read'
  #          }

  # Additional configuration
  configure do |config|
    config.path_prefix = '/users/auth'
  end
end

# CSRF Protection for OmniAuth
# SECURITY FIX: Only allow POST requests to prevent CSRF attacks
# GET requests expose OAuth state parameters in URLs (browser history, logs, referrers)
# This is a critical security vulnerability (CVE-2015-9284)
# Reference: https://nvd.nist.gov/vuln/detail/CVE-2015-9284
OmniAuth.config.allowed_request_methods = [:post]
# Remove the silence_get_warning since we're properly using POST only
# OmniAuth.config.silence_get_warning = true
