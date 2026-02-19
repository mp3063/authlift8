# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, "lockable", type: :model do
  let(:user) { create(:user) }

  describe "lockable module" do
    it "includes :lockable in devise modules" do
      expect(User.devise_modules).to include(:lockable)
    end

    it "starts with zero failed attempts" do
      expect(user.failed_attempts).to eq(0)
    end

    it "is not locked by default" do
      expect(user.access_locked?).to be false
    end
  end

  describe "#lock_access!" do
    it "locks the account" do
      user.lock_access!
      expect(user.reload.access_locked?).to be true
      expect(user.locked_at).to be_present
    end
  end

  describe "#unlock_access!" do
    before { user.lock_access! }

    it "unlocks the account" do
      user.unlock_access!
      expect(user.reload.access_locked?).to be false
      expect(user.locked_at).to be_nil
      expect(user.failed_attempts).to eq(0)
    end
  end

  describe "auto-unlock after time period" do
    before { user.lock_access! }

    it "remains locked before unlock_in period" do
      travel_to 29.minutes.from_now do
        expect(user.access_locked?).to be true
      end
    end

    it "auto-unlocks after unlock_in period" do
      travel_to 31.minutes.from_now do
        expect(user.access_locked?).to be false
      end
    end
  end

  describe "failed attempt tracking" do
    it "increments failed_attempts on invalid authentication" do
      user.valid_for_authentication? { false }
      expect(user.reload.failed_attempts).to eq(1)
    end

    it "locks account after maximum_attempts" do
      Devise.maximum_attempts.times do
        user.valid_for_authentication? { false }
      end
      expect(user.reload.access_locked?).to be true
    end

    it "resets failed_attempts when unlocked" do
      3.times { user.valid_for_authentication? { false } }
      expect(user.reload.failed_attempts).to eq(3)

      user.unlock_access!
      expect(user.reload.failed_attempts).to eq(0)
    end
  end
end
