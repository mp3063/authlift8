# frozen_string_literal: true

# CurrentAttributes for request-scoped state.
# Automatically reset between requests by Rails.
#
# Primary use: propagate correlation IDs (X-Request-Id) across
# inter-service HTTP calls for distributed tracing.
#
class Current < ActiveSupport::CurrentAttributes
  attribute :request_id
end
