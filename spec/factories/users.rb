FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'password123' }
    first_name { 'Test' }
    last_name { 'User' }
    locale { 'en' }
    admin { false }
    super_admin { false }

    trait :super_admin do
      super_admin { true }
    end

    trait :admin do
      admin { true }
    end
  end
end
