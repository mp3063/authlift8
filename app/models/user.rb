# app/models/user.rb
class User < ApplicationRecord
  # Audit trail for security-sensitive changes
  # audited
  # Migration needed: rails g migration AddSuperAdminToUsers super_admin:boolean
  # Then run: rails db:migrate

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :trackable, :omniauthable,
         omniauth_providers: [:google_oauth2]

  # Associations
  belongs_to :company, optional: true  # Direct company for current context

  has_many :memberships, dependent: :destroy
  has_many :companies, through: :memberships
  has_many :oauth_access_tokens,
           class_name: 'Doorkeeper::AccessToken',
           foreign_key: :resource_owner_id,
           dependent: :delete_all
  has_many :oauth_access_grants,
           class_name: 'Doorkeeper::AccessGrant',
           foreign_key: :resource_owner_id,
           dependent: :delete_all

  # Validations
  validates :email, presence: true, uniqueness: true
  validates :first_name, presence: true
  validates :last_name, presence: true

  # Scopes
  scope :active, -> { where.not(email: nil) }
  scope :super_admins, -> { where(super_admin: true) }

  # Current company context
  # SECURITY: Only returns company if user has active membership
  def current_company
    # Use direct company if set and has active membership
    if company && memberships.active.exists?(company: company)
      company
    else
      # Fall back to first company with active membership
      memberships.active.includes(:company).first&.company
    end
  end

  def current_company=(new_company)
    # SECURITY: Only allow setting company if user has active membership
    if new_company.nil? || memberships.active.exists?(company: new_company)
      update(company: new_company)
    else
      Rails.logger.warn "SECURITY: User #{id} attempted to set current_company to #{new_company.id} without active membership"
      false
    end
  end

  def current_membership
    # SECURITY: Only returns active membership
    memberships.active.find_by(company: current_company) if current_company
  end

  # Full name
  def full_name
    "#{first_name} #{last_name}".strip
  end

  # Scopes - combines user-level + membership scopes
  def all_scopes(company: nil)
    user_scopes = (scopes || '').split(',').map(&:strip)

    target_company = company || current_company
    membership = target_company ? memberships.find_by(company: target_company) : nil
    membership_scopes = membership&.scopes || []

    (user_scopes + membership_scopes).uniq
  end

  # Check if user has scope - company-scoped authorization
  # @param scope [String, Symbol] The scope to check
  # @param company [Company, nil] Optional company context (defaults to current_company)
  # @return [Boolean] true if user has the scope
  def has_scope?(scope, company: nil)
    # Super admins have global access across all companies
    return true if super_admin?

    target_company = company || current_company
    return false unless target_company

    # Find active membership for the target company
    membership = memberships.find_by(company: target_company, active: true)
    return false unless membership

    # Company-level admins (owner or admin role) have all scopes within their company
    return true if membership.owner? || membership.admin?

    # Check if scope exists in combined user + membership scopes
    all_scopes(company: target_company).include?(scope.to_s)
  end

  # Super admin check - platform-level access
  def super_admin?
    super_admin == true
  end

  # Check if user is admin for a specific company
  def admin_for?(target_company)
    return true if super_admin?

    membership = memberships.find_by(company: target_company, active: true)
    membership&.owner? || membership&.admin?
  end

  # OmniAuth
  def self.from_omniauth(auth)
    where(email: auth.info.email).first_or_create do |user|
      user.email = auth.info.email
      user.password = Devise.friendly_token[0, 20]
      user.first_name = auth.info.first_name || auth.info.name&.split&.first || ''
      user.last_name = auth.info.last_name || auth.info.name&.split&.last || ''
    end
  end
end
