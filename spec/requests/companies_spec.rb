# spec/requests/companies_spec.rb
require 'rails_helper'

RSpec.describe 'Companies', type: :request do
  let(:user) { create(:user) }
  let(:company1) { create(:company) }
  let(:company2) { create(:company) }
  let(:membership1) { create(:membership, :owner, user: user, company: company1) }
  let(:membership2) { create(:membership, user: user, company: company2) }

  before do
    membership1
    membership2
    user.update(company: company1)
  end

  describe 'POST /switch_company/:id' do
    context 'when user is authenticated' do
      before { sign_in user }

      context 'when switching to a company user has access to' do
        it 'returns http redirect' do
          post switch_company_path(company2)
          expect(response).to have_http_status(:redirect)
        end

        it 'updates user current company' do
          expect {
            post switch_company_path(company2)
          }.to change { user.reload.company }.from(company1).to(company2)
        end

        it 'redirects to dashboard' do
          post switch_company_path(company2)
          expect(response).to redirect_to(dashboard_path)
        end

        it 'sets success flash message' do
          post switch_company_path(company2)
          expect(flash[:notice]).to eq("Switched to #{company2.name}")
        end

        context 'with return_to parameter' do
          it 'redirects to return_to path' do
            post switch_company_path(company2), params: { return_to: '/some/path' }
            expect(response).to redirect_to('/some/path')
          end
        end
      end

      context 'when switching to a company user does not have access to' do
        let(:other_company) { create(:company) }

        it 'does not update user current company' do
          expect {
            post switch_company_path(other_company)
          }.not_to change { user.reload.company }
        end

        it 'redirects to dashboard' do
          post switch_company_path(other_company)
          expect(response).to redirect_to(dashboard_path)
        end

        it 'sets alert flash message' do
          post switch_company_path(other_company)
          expect(flash[:alert]).to eq("You don't have access to #{other_company.name}")
        end
      end

      context 'when switching to a company with inactive membership' do
        before { membership2.update(active: false) }

        it 'does not update user current company' do
          expect {
            post switch_company_path(company2)
          }.not_to change { user.reload.company }
        end

        it 'sets alert flash message' do
          post switch_company_path(company2)
          expect(flash[:alert]).to eq("You don't have access to #{company2.name}")
        end
      end

      context 'when company does not exist' do
        it 'redirects to dashboard' do
          post switch_company_path(id: 999999)
          expect(response).to redirect_to(dashboard_path)
        end

        it 'sets alert flash message' do
          post switch_company_path(id: 999999)
          expect(flash[:alert]).to eq('Company not found')
        end
      end

      context 'when company update fails' do
        before do
          allow_any_instance_of(User).to receive(:update).and_return(false)
        end

        it 'sets alert flash message' do
          post switch_company_path(company2)
          expect(flash[:alert]).to eq('Failed to switch company')
        end
      end
    end

    context 'when user is not authenticated' do
      it 'redirects to sign in' do
        post switch_company_path(company2)
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'does not update any company' do
        expect {
          post switch_company_path(company2)
        }.not_to change { user.reload.company }
      end
    end
  end
end
