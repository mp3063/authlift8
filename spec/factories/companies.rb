FactoryBot.define do
  factory :company do
    sequence(:code) { |n| "COMP#{n.to_s.rjust(6, '0')}" }
    sequence(:name) { |n| "Test Company #{n}" }
    email { 'company@example.com' }
    phone { '+1234567890' }
    locale { 'en' }
    active { true }
    info { {} }
    settings { {} }
  end
end
