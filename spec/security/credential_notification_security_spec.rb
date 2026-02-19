# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Credential Change Notification Security', type: :model do
  describe 'Devise security notification configuration' do
    it 'sends notification when email is changed' do
      expect(Devise.send_email_changed_notification).to be true
    end

    it 'sends notification when password is changed' do
      expect(Devise.send_password_change_notification).to be true
    end

    it 'has paranoid mode enabled to prevent user enumeration' do
      expect(Devise.paranoid).to be true
    end
  end

  describe 'Session timeout configuration' do
    it 'has timeoutable module enabled on User' do
      expect(User.devise_modules).to include(:timeoutable)
    end

    it 'configures session timeout to 2 hours' do
      expect(Devise.timeout_in).to eq(2.hours)
    end
  end

  describe 'Email change notification delivery' do
    let(:user) { create(:user, email: 'original@example.com') }

    it 'sends notification to original email when email is changed' do
      expect {
        user.update(email: 'new_email@example.com')
      }.to change { ActionMailer::Base.deliveries.count }.by_at_least(1)

      notification = ActionMailer::Base.deliveries.find { |m| m.to.include?('original@example.com') }
      expect(notification).to be_present
    end
  end

  describe 'Password change notification delivery' do
    let(:user) { create(:user) }

    it 'sends notification when password is changed' do
      expect {
        user.update(password: 'new_secure_password_123', password_confirmation: 'new_secure_password_123')
      }.to change { ActionMailer::Base.deliveries.count }.by_at_least(1)
    end
  end

  describe 'Paranoid mode behavior', type: :request do
    it 'returns identical responses for existing and non-existing emails on password reset' do
      create(:user, email: 'exists@example.com')

      # Request password reset for existing email
      post user_password_path, params: { user: { email: 'exists@example.com' } }
      existing_response = response

      # Request password reset for non-existing email
      post user_password_path, params: { user: { email: 'nonexistent@example.com' } }
      nonexistent_response = response

      # Paranoid mode: both should redirect (303 See Other with Turbo)
      expect(existing_response.status).to eq(nonexistent_response.status)
    end
  end

  describe 'Audit trail' do
    let(:user) { create(:user) }

    it 'creates an audit record when email is changed' do
      expect {
        user.update(email: 'audited_change@example.com')
      }.to change { user.audits.count }.by(1)

      audit = user.audits.last
      expect(audit.audited_changes).to have_key('email')
    end

    it 'creates an audit record when password is changed' do
      expect {
        user.update(password: 'new_audited_password_123', password_confirmation: 'new_audited_password_123')
      }.to change { user.audits.count }.by(1)

      audit = user.audits.last
      expect(audit.audited_changes).to have_key('encrypted_password')
    end

    it 'creates an audit record when admin flag is changed' do
      expect {
        user.update(admin: true)
      }.to change { user.audits.count }.by(1)

      audit = user.audits.last
      expect(audit.audited_changes).to have_key('admin')
    end

    it 'creates an audit record when super_admin flag is changed' do
      expect {
        user.update(super_admin: true)
      }.to change { user.audits.count }.by(1)

      audit = user.audits.last
      expect(audit.audited_changes).to have_key('super_admin')
    end

    it 'creates an audit record when company is changed' do
      company = create(:company)
      create(:membership, user: user, company: company, active: true)

      expect {
        user.update(company: company)
      }.to change { user.audits.count }.by(1)

      audit = user.audits.last
      expect(audit.audited_changes).to have_key('company_id')
    end

    it 'does NOT audit non-sensitive attribute changes' do
      expect {
        user.update(first_name: 'NewName')
      }.not_to change { user.audits.count }
    end

    it 'records the action type as update' do
      user.update(email: 'action_type_test@example.com')
      expect(user.audits.last.action).to eq('update')
    end

    it 'records create action for new users' do
      new_user = create(:user)
      expect(new_user.audits.last.action).to eq('create')
    end
  end

  describe 'Mailer sender configuration' do
    it 'does not use the default Devise placeholder sender' do
      expect(Devise.mailer_sender).not_to include('please-change-me')
    end

    it 'does not use example.com as ApplicationMailer sender' do
      default_from = ApplicationMailer.default[:from]
      expect(default_from).not_to eq('from@example.com')
    end

    it 'uses the same MAILER_FROM env var for both Devise and ApplicationMailer' do
      # Both should read from the same ENV variable to avoid divergence
      devise_sender = Devise.mailer_sender
      app_sender = ApplicationMailer.default[:from]
      expect(devise_sender).to eq(app_sender)
    end
  end
end
