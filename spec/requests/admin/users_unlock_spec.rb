# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Users#unlock", type: :request do
  let(:super_admin) { create(:user, :super_admin) }
  let(:locked_user) { create(:user) }

  before do
    locked_user.lock_access!
    sign_in super_admin
  end

  describe "PATCH /admin/users/:id/unlock" do
    it "unlocks the user account" do
      expect(locked_user.access_locked?).to be true

      patch unlock_admin_user_path(locked_user)

      expect(locked_user.reload.access_locked?).to be false
      expect(locked_user.failed_attempts).to eq(0)
      expect(locked_user.locked_at).to be_nil
    end

    it "redirects to user show page with notice" do
      patch unlock_admin_user_path(locked_user)

      expect(response).to redirect_to(admin_user_path(locked_user))
      expect(flash[:notice]).to eq("Account unlocked successfully.")
    end

    it "logs the security event" do
      allow(Rails.logger).to receive(:info).and_call_original

      patch unlock_admin_user_path(locked_user)

      expect(Rails.logger).to have_received(:info).with(
        /Admin #{super_admin.id}.*unlocked account #{locked_user.id}/
      )
    end

    context "when user is not locked" do
      before { locked_user.unlock_access! }

      it "succeeds without error" do
        patch unlock_admin_user_path(locked_user)

        expect(response).to redirect_to(admin_user_path(locked_user))
        expect(flash[:notice]).to eq("Account unlocked successfully.")
      end
    end

    context "when not authenticated" do
      before { sign_out super_admin }

      it "redirects to login" do
        patch unlock_admin_user_path(locked_user)

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when authenticated as non-admin" do
      let(:regular_user) { create(:user) }

      before do
        sign_out super_admin
        sign_in regular_user
      end

      it "denies access" do
        patch unlock_admin_user_path(locked_user)

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
