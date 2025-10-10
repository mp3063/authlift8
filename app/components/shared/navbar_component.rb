# frozen_string_literal: true

module Shared
  class NavbarComponent < ViewComponent::Base
    def initialize(current_user:)
      @current_user = current_user
    end

    private

    def user_companies
      @current_user&.companies || []
    end

    def current_company
      @current_user&.current_company
    end

    def user_initials
      return "?" unless @current_user

      first = @current_user.first_name&.first || ""
      last = @current_user.last_name&.first || ""
      "#{first}#{last}".upcase
    end

    def show_admin_link?
      @current_user&.super_admin?
    end

    def show_companies_link?
      @current_user&.super_admin? || company_admin?
    end

    def show_oauth_apps_link?
      @current_user&.super_admin? || company_admin?
    end

    def company_admin?
      return false unless @current_user && current_company

      @current_user.admin_for?(current_company)
    end
  end
end
