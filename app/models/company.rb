# app/models/company.rb
class Company < ApplicationRecord
  # Note: Audited gem requires migration: rails generate audited:install
  # audited

  # Associations
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships

  has_many :oauth_applications,
           class_name: 'Doorkeeper::Application',
           as: :owner,
           dependent: :destroy

  has_many :api_keys, dependent: :destroy
  has_many :customer_groups, dependent: :destroy

  # OAuth app access control (HABTM)
  has_and_belongs_to_many :allowed_applications,
                          class_name: 'Doorkeeper::Application',
                          join_table: :applications_companies,
                          foreign_key: :company_id,
                          association_foreign_key: :application_id

  # Application domains
  has_many :application_domains, dependent: :destroy

  # Partnerships - using partner_owner/partner_client structure
  # As owner (supplier/provider)
  has_many :owned_partnerships,
           class_name: 'Partnership',
           foreign_key: :partner_owner_id,
           dependent: :destroy
  has_many :clients, through: :owned_partnerships, source: :partner_client

  # As client (customer/buyer)
  has_many :client_partnerships,
           class_name: 'Partnership',
           foreign_key: :partner_client_id,
           dependent: :destroy
  has_many :suppliers, through: :client_partnerships, source: :partner_owner

  # Validations
  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  # Callbacks
  before_validation :generate_code, on: :create

  # Scopes
  scope :active, -> { where(active: true) }

  private

  def generate_code
    self.code ||= SecureRandom.alphanumeric(10).upcase
  end
end
