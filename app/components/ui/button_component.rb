# frozen_string_literal: true

module UI
  class ButtonComponent < ViewComponent::Base
    attr_reader :variant, :size, :type, :disabled

    VARIANT_CLASSES = {
      primary: "bg-blue-600 text-white hover:bg-blue-700 active:bg-blue-800 disabled:bg-blue-400",
      secondary: "bg-gray-200 text-gray-900 hover:bg-gray-300 active:bg-gray-400 disabled:bg-gray-100",
      danger: "bg-red-600 text-white hover:bg-red-700 active:bg-red-800 disabled:bg-red-400",
      success: "bg-green-600 text-white hover:bg-green-700 active:bg-green-800 disabled:bg-green-400",
      outline: "border-2 border-blue-600 text-blue-600 hover:bg-blue-50 active:bg-blue-100 disabled:border-gray-300 disabled:text-gray-300",
      ghost: "text-gray-700 hover:bg-gray-100 active:bg-gray-200 disabled:text-gray-400"
    }.freeze

    SIZE_CLASSES = {
      sm: "px-3 py-1.5 text-sm",
      md: "px-4 py-2 text-base",
      lg: "px-6 py-3 text-lg"
    }.freeze

    def initialize(variant: :primary, size: :md, type: "button", disabled: false, **html_options)
      @variant = variant
      @size = size
      @type = type
      @disabled = disabled
      @html_options = html_options
    end

    def call
      button_tag(content, **button_attributes)
    end

    private

    def button_attributes
      {
        type: type,
        disabled: disabled,
        class: classes
      }.merge(@html_options)
    end

    def classes
      base = "inline-flex items-center justify-center font-medium rounded-lg transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:cursor-not-allowed"

      [
        base,
        VARIANT_CLASSES[variant],
        SIZE_CLASSES[size],
        @html_options[:class]
      ].compact.join(" ")
    end
  end
end
