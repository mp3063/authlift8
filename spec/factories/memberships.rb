FactoryBot.define do
  factory :membership do
    user
    company
    role { 'member' }
    scopes { [] }
    info { {} }
    active { true }

    trait :owner do
      role { 'owner' }
    end

    trait :admin do
      role { 'admin' }
    end

    trait :with_scopes do
      scopes { ['products:read', 'products:write'] }
    end
  end
end
