# app/models/api_key.rb
class ApiKey < ApplicationRecord
  belongs_to :company

  # Validations
  validates :token, presence: true, uniqueness: true
  validates :name, presence: true

  # Callbacks
  before_validation :generate_token, on: :create

  # Scopes
  scope :active, -> { where(active: true) }
  scope :unexpired, -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }

  # Check if API key is valid
  def valid_key?
    active? && !expired?
  end

  # Check if API key has expired
  def expired?
    expires_at.present? && expires_at < Time.current
  end

  # Update last used timestamp
  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end

  # Scope management
  def has_scope?(scope)
    current_scopes = scopes.is_a?(Array) ? scopes : []
    current_scopes.include?(scope.to_s)
  end

  def add_scope(scope)
    current_scopes = scopes.is_a?(Array) ? scopes : []
    update(scopes: (current_scopes + [scope.to_s]).uniq)
  end

  def remove_scope(scope)
    current_scopes = scopes.is_a?(Array) ? scopes : []
    update(scopes: current_scopes - [scope.to_s])
  end

  private

  def generate_token
    self.token ||= SecureRandom.hex(32)
  end
end
