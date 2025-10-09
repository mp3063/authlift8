# app/models/doorkeeper/application.rb
module Doorkeeper
  class Application < ApplicationRecord
    include Doorkeeper::Orm::ActiveRecord::Mixins::Application

    # Multiple domains per app
    has_many :application_domains, dependent: :destroy, foreign_key: :oauth_application_id

    # Company access control (HABTM)
    has_and_belongs_to_many :companies,
                            join_table: :applications_companies,
                            foreign_key: :application_id

    # Partnership apps
    has_many :partnership_apps, dependent: :destroy, foreign_key: :oauth_application_id
    has_many :partnerships, through: :partnership_apps

    # Validations
    validates :home, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) },
              allow_blank: true

    # Helper methods
    def trusted?
      trusted == true
    end

    def allows_partnerships?
      partnerships_allowed == true
    end

    def allowed_domains_for(company = nil)
      if company
        application_domains.where(company: company).pluck(:domain)
      else
        application_domains.pluck(:domain)
      end
    end
  end
end
