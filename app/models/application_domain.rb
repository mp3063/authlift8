# app/models/application_domain.rb
class ApplicationDomain < ApplicationRecord
  belongs_to :oauth_application, class_name: 'Doorkeeper::Application'
  belongs_to :company

  # Validations
  validates :domain, presence: true,
            format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  validates :domain, uniqueness: { scope: :oauth_application_id }
end
