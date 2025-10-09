FactoryBot.define do
  factory :oauth_access_token, class: 'Doorkeeper::AccessToken' do
    association :application, factory: :oauth_application
    resource_owner_id { create(:user).id }
    expires_in { 7200 }
    scopes { 'public' }

    # Generate a unique token
    token { SecureRandom.hex(32) }
  end

  factory :oauth_application, class: 'Doorkeeper::Application' do
    sequence(:name) { |n| "Test Application #{n}" }
    sequence(:uid) { |n| "test-app-#{n}" }
    secret { SecureRandom.hex(32) }
    redirect_uri { 'urn:ietf:wg:oauth:2.0:oob' }
    scopes { 'public write' }
    confidential { true }
    trusted { false }
  end
end
