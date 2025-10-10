# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:each, type: :request) do
    # Configure allowed redirect hosts for Auth::Integration tests
    stub_const('Auth::IntegrationController::ALLOWED_REDIRECT_HOSTS', [ 'example.com', 'www.example.com' ])

    # Configure AUTHLIFT_URL for JWT issuer validation
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('AUTHLIFT_URL').and_return('http://www.example.com')
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('AUTHLIFT_URL').and_return('http://www.example.com')
  end
end
