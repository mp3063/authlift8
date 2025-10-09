# app/models/partnership_app.rb
class PartnershipApp < ApplicationRecord
  belongs_to :oauth_application, class_name: 'Doorkeeper::Application'
  belongs_to :partnership

  validates :oauth_application_id, uniqueness: { scope: :partnership_id }

  scope :active, -> { where(active: true) }
end
