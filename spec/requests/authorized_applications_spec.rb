# frozen_string_literal: true

require "rails_helper"

RSpec.describe "AuthorizedApplications", type: :request do
  let(:user) { create(:user) }
  let(:company) { create(:company) }
  let(:membership) { create(:membership, :owner, user: user, company: company) }
  let(:oauth_app) { create(:oauth_application, owner: company) }

  before do
    membership
    user.update(company: company)
  end

  describe "GET /authorized_applications" do
    context "when not authenticated" do
      it "redirects to sign in" do
        get authorized_applications_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when authenticated" do
      before { sign_in user }

      it "returns http success" do
        get authorized_applications_path
        expect(response).to have_http_status(:success)
      end

      it "lists applications with active tokens" do
        create(:oauth_access_token, application_id: oauth_app.id, resource_owner_id: user.id)

        get authorized_applications_path
        expect(response.body).to include(oauth_app.name)
      end

      it "does not list applications with only revoked tokens" do
        create(:oauth_access_token, application_id: oauth_app.id, resource_owner_id: user.id,
               revoked_at: Time.current)

        get authorized_applications_path
        expect(response.body).not_to include(oauth_app.name)
      end

      it "does not list other users' authorized applications" do
        other_user = create(:user)
        create(:oauth_access_token, application_id: oauth_app.id, resource_owner_id: other_user.id)

        get authorized_applications_path
        expect(response.body).not_to include(oauth_app.name)
      end

      it "shows empty state when no applications are authorized" do
        get authorized_applications_path
        expect(response.body).to include("No authorized applications")
      end

      it "shows active token count" do
        create_list(:oauth_access_token, 3, application_id: oauth_app.id, resource_owner_id: user.id)

        get authorized_applications_path
        expect(response.body).to include("3 active tokens")
      end
    end
  end

  describe "DELETE /authorized_applications/:id" do
    context "when not authenticated" do
      it "redirects to sign in" do
        delete authorized_application_path(oauth_app)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when authenticated" do
      before { sign_in user }

      it "revokes all tokens for the application" do
        tokens = create_list(:oauth_access_token, 3, application_id: oauth_app.id, resource_owner_id: user.id)

        delete authorized_application_path(oauth_app)

        tokens.each do |token|
          expect(token.reload.revoked_at).not_to be_nil
        end
      end

      it "also revokes previously-refreshed tokens" do
        refreshed_token = create(:oauth_access_token, application_id: oauth_app.id,
                                 resource_owner_id: user.id, revoked_at: 1.minute.ago)
        # Need an active token so the app shows up in authorized_applications_for
        create(:oauth_access_token, application_id: oauth_app.id, resource_owner_id: user.id)

        delete authorized_application_path(oauth_app)

        refreshed_token.reload
        expect(refreshed_token.refresh_token).to be_nil
      end

      it "revokes pending access grants" do
        create(:oauth_access_token, application_id: oauth_app.id, resource_owner_id: user.id)
        grant = create(:oauth_access_grant, application_id: oauth_app.id, resource_owner_id: user.id)

        delete authorized_application_path(oauth_app)

        expect(grant.reload.revoked_at).not_to be_nil
      end

      it "does not revoke other users' tokens for the same application" do
        other_user = create(:user)
        other_token = create(:oauth_access_token, application_id: oauth_app.id, resource_owner_id: other_user.id)
        create(:oauth_access_token, application_id: oauth_app.id, resource_owner_id: user.id)

        delete authorized_application_path(oauth_app)

        expect(other_token.reload.revoked_at).to be_nil
      end

      it "redirects to authorized applications index" do
        create(:oauth_access_token, application_id: oauth_app.id, resource_owner_id: user.id)

        delete authorized_application_path(oauth_app)
        expect(response).to redirect_to(authorized_applications_path)
      end

      it "shows flash confirmation" do
        create(:oauth_access_token, application_id: oauth_app.id, resource_owner_id: user.id)

        delete authorized_application_path(oauth_app)
        expect(flash[:notice]).to eq("Application revoked.")
      end

      it "no longer shows application in index after revocation" do
        create(:oauth_access_token, application_id: oauth_app.id, resource_owner_id: user.id)

        delete authorized_application_path(oauth_app)
        follow_redirect!

        expect(response.body).not_to include(oauth_app.name)
      end

      it "returns alert for non-existent application" do
        delete authorized_application_path(id: 999_999)

        expect(response).to redirect_to(authorized_applications_path)
        expect(flash[:alert]).to eq("Application not found.")
      end

      it "returns alert when user has not authorized the application" do
        # App exists but user has no tokens for it
        other_app = create(:oauth_application)

        delete authorized_application_path(other_app)

        expect(response).to redirect_to(authorized_applications_path)
        expect(flash[:alert]).to eq("Application not found.")
      end

      it "logs the revocation event" do
        create(:oauth_access_token, application_id: oauth_app.id, resource_owner_id: user.id)

        allow(Rails.logger).to receive(:info).and_call_original

        delete authorized_application_path(oauth_app)

        expect(Rails.logger).to have_received(:info).with(/SECURITY: OAuth token revocation/)
      end
    end
  end
end
