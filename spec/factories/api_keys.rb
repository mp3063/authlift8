# spec/factories/api_keys.rb
FactoryBot.define do
  factory :api_key do
    association :company
    name { Faker::App.name }
    active { true }
    expires_at { nil }
    scopes { [] }

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :inactive do
      active { false }
    end

    trait :with_scopes do
      scopes { %w[read write admin] }
    end
  end
end
