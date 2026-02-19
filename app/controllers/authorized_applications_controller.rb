# frozen_string_literal: true

class AuthorizedApplicationsController < ApplicationController
  before_action :authenticate_user!

  # GET /authorized_applications
  def index
    @authorized_apps = authorized_applications_for(current_user)
  end

  # DELETE /authorized_applications/:id
  def destroy
    application = authorized_applications_for(current_user).find_by(id: params[:id])

    unless application
      redirect_to authorized_applications_path, alert: "Application not found."
      return
    end

    # Revoke ALL tokens (including previously-refreshed ones with valid refresh_tokens)
    revoked_count = Doorkeeper::AccessToken.where(
      resource_owner_id: current_user.id,
      application_id: application.id
    ).update_all(revoked_at: Time.current, refresh_token: nil)

    # Also revoke any pending access grants
    Doorkeeper::AccessGrant.where(
      resource_owner_id: current_user.id,
      application_id: application.id,
      revoked_at: nil
    ).update_all(revoked_at: Time.current)

    Rails.logger.info(
      "SECURITY: OAuth token revocation — " \
      "User ID: #{current_user.id}, Email: #{current_user.email}, " \
      "Application ID: #{application.id}, Application: #{application.name}, " \
      "Tokens revoked: #{revoked_count}"
    )

    redirect_to authorized_applications_path,
                notice: t("doorkeeper.flash.authorized_applications.destroy.notice")
  end

  private

  def authorized_applications_for(user)
    token_table = Doorkeeper::AccessToken.arel_table

    Doorkeeper::Application
      .joins(:access_tokens)
      .where(token_table[:resource_owner_id].eq(user.id))
      .where(token_table[:revoked_at].eq(nil))
      .select(
        "oauth_applications.*",
        "COUNT(oauth_access_tokens.id) AS active_token_count",
        "MIN(oauth_access_tokens.created_at) AS first_authorized_at",
        "MAX(oauth_access_tokens.created_at) AS last_authorized_at",
        "STRING_AGG(DISTINCT oauth_access_tokens.scopes, ' ') AS token_scopes"
      )
      .group("oauth_applications.id")
      .order("last_authorized_at DESC")
  end
end
