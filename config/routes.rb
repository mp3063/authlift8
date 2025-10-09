Rails.application.routes.draw do
  # Devise authentication
  devise_for :users, controllers: {
    omniauth_callbacks: 'omniauth_callbacks',
    sessions: 'users/sessions',
    registrations: 'users/registrations'
  }

  # Doorkeeper OAuth2 provider
  use_doorkeeper do
    skip_controllers :applications, :authorized_applications
  end

  # Root path
  root 'dashboard#index'

  # Dashboard
  resource :dashboard, only: [:show]

  # Company switching
  post 'switch_company/:id', to: 'companies#switch', as: :switch_company

  # Admin routes
  namespace :admin do
    resources :users
    resources :companies do
      resources :memberships
      resources :partnerships
    end
    resources :oauth_applications
    resources :api_keys
  end

  # Integration endpoints (for client apps - NO GEM NEEDED!)
  # Security: State-changing operations use only POST/DELETE to prevent CSRF attacks
  namespace :auth do
    # Check if user is logged in (for client apps) - GET allowed (read-only)
    get 'check_login', to: 'integration#check_login'

    # Remote logout (destroys all tokens) - DELETE only to prevent CSRF
    delete 'logout', to: 'integration#logout'

    # Company switching (returns new JWT with new company context) - POST only to prevent CSRF
    post 'switch_company', to: 'integration#switch_company'

    # Language switching - POST only to prevent CSRF
    post 'change_language', to: 'integration#change_language'
  end

  # API routes
  namespace :api do
    namespace :v1 do
      # Public key endpoints (no authentication required)
      get '.well-known/jwks.json', to: 'public_keys#jwks'
      get 'public_key.pem', to: 'public_keys#pem'

      # User endpoints (OAuth authentication required)
      get 'users/profile', to: 'users#profile'
      get 'users/company_info(/:company_id)', to: 'users#company_info'

      # Company endpoints (OAuth authentication required)
      resources :companies, only: [:index, :show]

      # API Key authentication
      post 'auth/api_key', to: 'auth#api_key'
    end
  end

  # Health check endpoint
  get 'up', to: 'health#show'
end
