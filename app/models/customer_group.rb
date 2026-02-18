# app/models/customer_group.rb
class CustomerGroup < ApplicationRecord
  belongs_to :company

  # Validations
  validates :name, presence: true, uniqueness: { scope: :company_id }
  validates :group_type, inclusion: { in: %w[wholesale retail vip partner] },
            allow_nil: true

  # Scopes
  scope :enabled, -> { where(enabled: true) }

  # Session invalidation callback
  after_commit :invalidate_session_version, on: [ :create, :update, :destroy ]

  # Check if product is allowed for this group
  def product_allowed?(product_id)
    return true if product_restriction_rules.blank?

    allowed_ids = product_restriction_rules["allowed_product_ids"] || []
    excluded_ids = product_restriction_rules["excluded_product_ids"] || []

    return false if excluded_ids.include?(product_id)
    return true if allowed_ids.empty? || allowed_ids.include?(product_id)
    false
  end

  # Get pricing for product
  def price_for_product(product_id, base_price)
    return base_price if pricing_rules.blank?

    multiplier = pricing_rules["price_multiplier"] || 1.0
    discount = pricing_rules["discount_percentage"] || 0

    price = base_price * multiplier
    price -= (price * discount / 100.0)
    price
  end

  private

  def invalidate_session_version
    SessionVersionService.invalidate_customer_groups(company)
  end
end
