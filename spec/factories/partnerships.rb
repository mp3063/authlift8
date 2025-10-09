FactoryBot.define do
  factory :partnership do
    association :partner_owner, factory: :company
    association :partner_client, factory: :company
    info { {} }
    settings { {} }
    managed_company { false }
    active { true }

    # Override to prevent self-partnership (validation error)
    transient do
      ensure_different_companies { true }
    end

    after(:build) do |partnership, evaluator|
      if evaluator.ensure_different_companies && partnership.partner_owner == partnership.partner_client
        partnership.partner_client = create(:company)
      end
    end

    trait :managed do
      managed_company { true }
    end

    trait :inactive do
      active { false }
    end

    trait :with_info do
      info { { established_date: '2025-01-01', contract_number: 'CNT-001' } }
    end

    trait :with_settings do
      settings { { auto_sync: true, sync_interval: 'hourly' } }
    end
  end
end
