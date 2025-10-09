# frozen_string_literal: true

module UI
  class ModalComponent < ViewComponent::Base
    renders_one :header
    renders_one :footer

    def initialize(id:, size: :md, **html_options)
      @id = id
      @size = size
      @html_options = html_options
    end

    private

    SIZE_CLASSES = {
      sm: "max-w-md",
      md: "max-w-lg",
      lg: "max-w-2xl",
      xl: "max-w-4xl",
      full: "max-w-full mx-4"
    }.freeze

    def modal_classes
      base = "relative bg-white rounded-lg shadow-xl w-full"
      [base, SIZE_CLASSES[@size]].join(" ")
    end

    def backdrop_classes
      "fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"
    end

    def container_classes
      "fixed inset-0 z-50 overflow-y-auto"
    end

    def wrapper_classes
      "flex min-h-full items-center justify-center p-4 text-center sm:p-0"
    end
  end
end
