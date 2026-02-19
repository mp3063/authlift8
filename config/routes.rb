Rails.application.routes.draw do
  # Devise authentication
  devise_for :users, controllers: {
    omniauth_callbacks: "users/omniauth_callbacks",
    sessions: "users/sessions",
    registrations: "users/registrations"
  }

  # OmniAuth failure route (handled by Devise but needs explicit routing)
  devise_scope :user do
    get "/users/auth/failure", to: "users/omniauth_callbacks#failure"
  end

  # Doorkeeper OAuth2 provider
  use_doorkeeper do
    skip_controllers :applications, :authorized_applications
  end

  # Root path
  root "dashboard#index"

  # Dashboard
  resource :dashboard, only: [ :show ], controller: "dashboard"

  # Authorized applications (user self-service: view and revoke OAuth access)
  resources :authorized_applications, only: [ :index, :destroy ]

  # Company switching
  post "switch_company/:id", to: "companies#switch", as: :switch_company

  # Admin routes (add named route for tests)
  get "/admin", to: "admin/dashboard#index", as: "admin"

  namespace :admin do
    root "dashboard#index"
    get "dashboard", to: "dashboard#index"

    resources :users do
      member do
        post :add_to_company
        patch :unlock
      end
    end
    resources :companies do
      resources :memberships
      resources :partnerships do
        resources :partnership_apps, only: [ :create, :destroy ]
      end
      resources :customer_groups
    end
    resources :oauth_applications
    resources :api_keys
  end

  # Integration endpoints (for client apps - NO GEM NEEDED!)
  # Security: State-changing operations use only POST/DELETE to prevent CSRF attacks
  namespace :auth do
    # Check if user is logged in (for client apps) - GET allowed (read-only)
    get "check_login", to: "integration#check_login"

    # Remote logout (destroys all tokens) - DELETE preferred, GET for compatibility
    delete "logout", to: "integration#logout"
    get "logout", to: "integration#logout"

    # Company switching (returns new JWT with new company context) - POST preferred, GET for compatibility
    post "switch_company", to: "integration#switch_company"
    get "switch_company", to: "integration#switch_company"

    # Language switching - POST preferred, GET for compatibility
    post "change_language", to: "integration#change_language"
    get "change_language", to: "integration#change_language"
  end

  # API routes
  namespace :api do
    namespace :v1 do
      # Public key endpoints (no authentication required)
      get ".well-known/jwks.json", to: "public_keys#jwks"
      get "public_key.pem", to: "public_keys#pem"

      # User endpoints (OAuth authentication required)
      get "users/profile", to: "users#profile"
      get "users/company_info(/:company_id)", to: "users#company_info"

      # Company endpoints (OAuth authentication required)
      resources :companies, only: [ :index, :show ]

      # API Key authentication
      post "auth/api_key", to: "auth#api_key"
    end
  end

  # Health check endpoint
  get "up", to: "health#show"
end
