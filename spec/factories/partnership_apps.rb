FactoryBot.define do
  factory :partnership_app do
    association :partnership
    association :oauth_application, factory: :oauth_application

    active { true }

    trait :inactive do
      active { false }
    end
  end
end
