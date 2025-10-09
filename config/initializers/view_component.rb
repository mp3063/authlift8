# frozen_string_literal: true

# ViewComponent configuration
Rails.application.config.to_prepare do
  # Eagerly load all components to ensure they're available
  Dir[Rails.root.join("app/components/**/*.rb")].sort.each do |file|
    require_dependency file
  end
end
