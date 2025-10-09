# frozen_string_literal: true

module UI
  class CardComponent < ViewComponent::Base
    renders_one :header
    renders_one :footer

    def initialize(padding: true, shadow: true, **html_options)
      @padding = padding
      @shadow = shadow
      @html_options = html_options
    end

    private

    def classes
      base = "bg-white rounded-lg border border-gray-200"
      base += " shadow-md" if @shadow
      base += " overflow-hidden"

      [base, @html_options[:class]].compact.join(" ")
    end

    def body_classes
      @padding ? "p-6" : ""
    end

    def header_classes
      "px-6 py-4 border-b border-gray-200 bg-gray-50"
    end

    def footer_classes
      "px-6 py-4 border-t border-gray-200 bg-gray-50"
    end
  end
end
