# frozen_string_literal: true

module Shared
  class FlashComponent < ViewComponent::Base
    FLASH_TYPES = {
      notice: {
        icon: "check-circle",
        bg: "bg-green-50",
        border: "border-green-200",
        text: "text-green-800",
        icon_color: "text-green-400"
      },
      success: {
        icon: "check-circle",
        bg: "bg-green-50",
        border: "border-green-200",
        text: "text-green-800",
        icon_color: "text-green-400"
      },
      alert: {
        icon: "exclamation-circle",
        bg: "bg-red-50",
        border: "border-red-200",
        text: "text-red-800",
        icon_color: "text-red-400"
      },
      error: {
        icon: "exclamation-circle",
        bg: "bg-red-50",
        border: "border-red-200",
        text: "text-red-800",
        icon_color: "text-red-400"
      },
      warning: {
        icon: "exclamation-triangle",
        bg: "bg-yellow-50",
        border: "border-yellow-200",
        text: "text-yellow-800",
        icon_color: "text-yellow-400"
      },
      info: {
        icon: "information-circle",
        bg: "bg-blue-50",
        border: "border-blue-200",
        text: "text-blue-800",
        icon_color: "text-blue-400"
      }
    }.freeze

    def initialize(flash:)
      @flash = flash
    end

    def render?
      @flash.any?
    end

    private

    def flash_config(type)
      FLASH_TYPES[type.to_sym] || FLASH_TYPES[:info]
    end

    def icon_svg(type)
      config = flash_config(type)

      case config[:icon]
      when "check-circle"
        '<svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" /></svg>'
      when "exclamation-circle"
        '<svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" /></svg>'
      when "exclamation-triangle"
        '<svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" /></svg>'
      when "information-circle"
        '<svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" /></svg>'
      end
    end
  end
end
