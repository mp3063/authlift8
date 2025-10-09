require 'rails_helper'

RSpec.describe 'Debug Whitelist', type: :request do
  it 'debugs whitelist' do
    puts "\n=== DEBUG INFO ==="
    puts "ENV['ALLOWED_ORIGINS']: #{ENV['ALLOWED_ORIGINS']}"
    puts "ALLOWED_REDIRECT_HOSTS: #{Auth::IntegrationController::ALLOWED_REDIRECT_HOSTS.inspect}"
    
    allowed_url = "#{ENV.fetch('ALLOWED_ORIGINS', 'http://localhost:3232').split(',').first}?test=1"
    puts "Test URL: #{allowed_url}"
    
    uri = URI.parse(allowed_url)
    puts "Parsed host: #{uri.host}"
    puts "==================\n"
    
    get '/auth/check_login', params: { return_to: allowed_url }
    
    puts "Response status: #{response.status}"
    puts "Response body: #{response.body}"
  end
end
