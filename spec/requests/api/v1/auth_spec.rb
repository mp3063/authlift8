# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Auth', type: :request do
  let(:company) { create(:company, name: 'Test Company') }
  let(:api_key) { create(:api_key, company: company, scopes: %w[read write]) }

  let(:public_key) do
    OpenSSL::PKey::RSA.new(
      Rails.application.credentials.dig(:doorkeeper, :private_key)
    ).public_key
  end

  def decode_jwt(token)
    JWT.decode(token, public_key, true, algorithm: 'RS256').first
  end

  describe 'POST /api/v1/auth/api_key' do
    context 'with valid API key via Bearer header' do
      it 'returns a JWT token' do
        post '/api/v1/auth/api_key', headers: { 'Authorization' => "Bearer #{api_key.token}" }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['token']).to be_present
        expect(body['expires_in']).to eq(3600)
        expect(body['token_type']).to eq('Bearer')
        expect(body['company_id']).to eq(company.id)
        expect(body['scopes']).to match_array(%w[read write])
      end

      it 'returns a valid RS256 JWT with correct claims' do
        post '/api/v1/auth/api_key', headers: { 'Authorization' => "Bearer #{api_key.token}" }

        body = JSON.parse(response.body)
        claims = decode_jwt(body['token'])

        expect(claims['iss']).to eq(ENV['AUTHLIFT_URL'])
        expect(claims['sub']).to eq("api_key:#{api_key.id}")
        expect(claims['company_id']).to eq(company.id)
        expect(claims['scopes']).to match_array(%w[read write])
        expect(claims['type']).to eq('api_key')
        expect(claims['jti']).to be_present
        expect(claims['exp']).to be > Time.now.to_i
      end

      it 'updates last_used_at' do
        expect { post '/api/v1/auth/api_key', headers: { 'Authorization' => "Bearer #{api_key.token}" } }
          .to change { api_key.reload.last_used_at }
      end
    end

    context 'with valid API key via body param' do
      it 'returns a JWT token' do
        post '/api/v1/auth/api_key', params: { api_key: api_key.token }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['token']).to be_present
      end
    end

    context 'with scope narrowing' do
      it 'returns only the requested scope when authorized' do
        post '/api/v1/auth/api_key',
             headers: { 'Authorization' => "Bearer #{api_key.token}" },
             params: { scope: 'read' }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['scopes']).to eq(['read'])

        claims = decode_jwt(body['token'])
        expect(claims['scopes']).to eq(['read'])
      end

      it 'returns 403 when requesting unauthorized scope' do
        post '/api/v1/auth/api_key',
             headers: { 'Authorization' => "Bearer #{api_key.token}" },
             params: { scope: 'admin' }

        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['error']).to eq('Scope not authorized')
      end
    end

    context 'with missing token' do
      it 'returns 401' do
        post '/api/v1/auth/api_key'

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['error']).to eq('Missing API key')
      end
    end

    context 'with invalid token' do
      it 'returns 401' do
        post '/api/v1/auth/api_key', headers: { 'Authorization' => 'Bearer invalid_token_here' }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['error']).to eq('Invalid API key')
      end

      it 'logs the failed attempt' do
        allow(Rails.logger).to receive(:warn).and_call_original

        post '/api/v1/auth/api_key', headers: { 'Authorization' => 'Bearer invalid_token_here' }

        expect(Rails.logger).to have_received(:warn).with(/SECURITY: API key auth failed.*not found/)
      end
    end

    context 'with expired API key' do
      let(:expired_key) { create(:api_key, :expired, company: company) }

      it 'returns 401' do
        post '/api/v1/auth/api_key', headers: { 'Authorization' => "Bearer #{expired_key.token}" }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['error']).to eq('API key is inactive or expired')
      end

      it 'logs the failure reason as expired' do
        allow(Rails.logger).to receive(:warn).and_call_original

        post '/api/v1/auth/api_key', headers: { 'Authorization' => "Bearer #{expired_key.token}" }

        expect(Rails.logger).to have_received(:warn).with(/expired/)
      end
    end

    context 'with inactive API key' do
      let(:inactive_key) { create(:api_key, :inactive, company: company) }

      it 'returns 401' do
        post '/api/v1/auth/api_key', headers: { 'Authorization' => "Bearer #{inactive_key.token}" }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['error']).to eq('API key is inactive or expired')
      end

      it 'logs the failure reason as inactive' do
        allow(Rails.logger).to receive(:warn).and_call_original

        post '/api/v1/auth/api_key', headers: { 'Authorization' => "Bearer #{inactive_key.token}" }

        expect(Rails.logger).to have_received(:warn).with(/inactive/)
      end
    end

    context 'with API key with no scopes' do
      let(:no_scope_key) { create(:api_key, company: company, scopes: []) }

      it 'returns a JWT with empty scopes' do
        post '/api/v1/auth/api_key', headers: { 'Authorization' => "Bearer #{no_scope_key.token}" }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['scopes']).to eq([])
      end
    end
  end
end
