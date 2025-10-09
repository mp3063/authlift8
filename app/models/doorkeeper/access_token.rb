# frozen_string_literal: true

module Doorkeeper
  class AccessToken < ApplicationRecord
    # Add resource_owner association for admin views
    belongs_to :resource_owner, class_name: 'User', foreign_key: 'resource_owner_id', optional: true

    self.table_name = 'oauth_access_tokens'
  end
end
