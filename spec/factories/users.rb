FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'password123456' }
    first_name { 'Test' }
    last_name { 'User' }
    locale { 'en' }
    admin { false }
    super_admin { false }
    sign_in_count { 1 }  # Non-zero so oauth_user? returns false

    trait :super_admin do
      super_admin { true }
    end

    trait :admin do
      admin { true }
    end

    trait :oauth_user do
      sign_in_count { 0 }
      first_name { nil }
      last_name { nil }
    end
  end
end
