# spec/support/devise.rb
RSpec.configure do |config|
  # Include Devise test helpers for request specs
  config.include Devise::Test::IntegrationHelpers, type: :request

  # Include Devise test helpers for controller specs
  config.include Devise::Test::ControllerHelpers, type: :controller

  # Ensure Devise mappings are loaded
  config.before(:suite) do
    # Reload Devise mappings if they're not loaded
    if Devise.mappings.empty?
      Rails.application.reload_routes!
    end
  end
end
