# frozen_string_literal: true

module Shared
  class FormErrorsComponent < ViewComponent::Base
    def initialize(model:)
      @model = model
    end

    def render?
      @model.present? && @model.errors.any?
    end

    private

    def error_count
      @model.errors.count
    end

    def error_message_header
      count = error_count
      "#{count} #{'error'.pluralize(count)} prohibited this #{@model.class.model_name.human.downcase} from being saved:"
    end
  end
end
