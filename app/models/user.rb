# app/models/user.rb
class User < ApplicationRecord
  # Audit trail for security-sensitive changes
  # audited
  # Migration needed: rails g migration AddSuperAdminToUsers super_admin:boolean
  # Then run: rails db:migrate

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :trackable, :omniauthable,
         omniauth_providers: [ :google_oauth2, :github, :facebook, :twitter ]

  # Associations
  belongs_to :company, optional: true  # Direct company for current context

  has_many :memberships, dependent: :destroy
  has_many :companies, through: :memberships
  has_many :oauth_access_tokens,
           class_name: "Doorkeeper::AccessToken",
           foreign_key: :resource_owner_id,
           dependent: :delete_all
  has_many :oauth_access_grants,
           class_name: "Doorkeeper::AccessGrant",
           foreign_key: :resource_owner_id,
           dependent: :delete_all

  # Validations
  validates :email, presence: true, uniqueness: true
  validates :first_name, presence: true, unless: :oauth_user?
  validates :last_name, presence: true, unless: :oauth_user?

  # Scopes
  scope :active, -> { where.not(email: nil) }
  scope :admins, -> { where(admin: true) }
  scope :super_admins, -> { where(super_admin: true) }

  # Session invalidation callback
  after_commit :invalidate_session_version, on: [ :update ]

  # Current company context
  # SECURITY: Only returns company if user has an active membership
  def current_company
    # Return nil if no company is assigned
    return nil unless company

    # Only return company if user has an active membership
    memberships.active.exists?(company: company) ? company : nil
  end

  def current_company=(new_company)
    # Allow setting company to nil
    if new_company.nil?
      update(company: nil)
      return true
    end

    # SECURITY: Validate active membership before allowing company assignment
    unless memberships.active.exists?(company: new_company)
      Rails.logger.warn("SECURITY: User #{id} attempted to set current_company to #{new_company.id} without active membership")
      return false
    end

    update(company: new_company)
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
    user_scopes = (scopes || "").split(",").map(&:strip)

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

    # User-level admins have access to any scope (legacy support)
    return true if admin?

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

  # Admin check - user-level admin access
  def admin?
    admin == true
  end

  # Check if user is admin for a specific company
  def admin_for?(target_company)
    return true if super_admin?

    membership = memberships.find_by(company: target_company, active: true)
    return false unless membership

    membership.owner? || membership.admin?
  end

  # Check if user was created via OAuth (for validation logic)
  def oauth_user?
    # OAuth users have randomly generated passwords and no sign_in_count initially
    encrypted_password.present? && sign_in_count.to_i.zero? && (first_name.blank? || last_name.blank?)
  end

  # OmniAuth
  def self.from_omniauth(auth)
    user = where(email: auth.info.email).first_or_initialize do |u|
      u.email = auth.info.email
      u.password = Devise.friendly_token[0, 20]
      u.first_name = auth.info.first_name || auth.info.name&.split&.first || ""
      u.last_name = auth.info.last_name || auth.info.name&.split&.last || ""
    end

    # Create a personal company for new OAuth users
    if user.new_record? && user.company.nil?
      company = Company.create!(
        name: "#{user.email}'s Company",
        active: true
      )
      user.company = company
      user.save!

      # Create owner membership
      Membership.create!(
        user: user,
        company: company,
        role: "owner",
        active: true
      )
    end

    user
  end

  private

  def invalidate_session_version
    # Only invalidate on relevant attribute changes
    relevant_changes = %w[email first_name last_name locale admin super_admin company_id]
    return unless relevant_changes.any? { |attr| saved_change_to_attribute?(attr) }

    SessionVersionService.invalidate_user(self)
  end
end
