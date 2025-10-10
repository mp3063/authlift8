# app/models/partnership.rb
class Partnership < ApplicationRecord
  # Owner = Supplier/Service Provider
  belongs_to :partner_owner, class_name: "Company"

  # Client = Customer/Buyer
  belongs_to :partner_client, class_name: "Company"

  # Partnership apps
  has_many :partnership_apps, dependent: :destroy
  has_many :oauth_applications, through: :partnership_apps

  # Validations
  validates :partner_owner_id, uniqueness: { scope: :partner_client_id }
  validate :cannot_partner_with_self, if: -> { partner_owner_id.present? && partner_client_id.present? }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :managed, -> { where(managed_company: true) }

  private

  def cannot_partner_with_self
    if partner_owner_id.present? && partner_client_id.present? && partner_owner_id == partner_client_id
      errors.add(:base, "cannot partner with self")
      errors.add(:partner_client_id, "cannot be the same as owner")
    end
  end
end
