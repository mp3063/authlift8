# app/models/membership.rb
class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :company

  # Validations
  validates :role, presence: true, inclusion: { in: %w[owner admin member] }
  validates :user_id, uniqueness: { scope: :company_id }

  # Session invalidation callback
  after_commit :invalidate_session_version, on: [:create, :update, :destroy]

  # Scopes
  scope :active, -> { where(active: true) }
  scope :owners, -> { where(role: "owner") }
  scope :admins, -> { where(role: "admin") }

  # Role checks
  def owner?
    role == "owner"
  end

  def admin?
    role == "admin"
  end

  def member?
    role == "member"
  end

  # Scope management
  def add_scope(scope)
    current_scopes = scopes.is_a?(Array) ? scopes : []
    update(scopes: (current_scopes + [ scope.to_s ]).uniq)
  end

  def remove_scope(scope)
    current_scopes = scopes.is_a?(Array) ? scopes : []
    update(scopes: current_scopes - [ scope.to_s ])
  end

  def has_scope?(scope)
    return true if owner? || admin?
    current_scopes = scopes.is_a?(Array) ? scopes : []
    current_scopes.include?(scope.to_s)
  end

  private

  def invalidate_session_version
    SessionVersionService.invalidate_user(user)
    SessionVersionService.invalidate_company(company)
  end
end
