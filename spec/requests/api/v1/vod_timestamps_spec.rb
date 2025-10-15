require 'rails_helper'

RSpec.describe 'VOD Timestamps API', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :analyst, organization: organization) }
  let(:admin) { create(:user, :admin, organization: organization) }
  let(:vod_review) { create(:vod_review, organization: organization) }
  let(:other_organization) { create(:organization) }
  let(:other_vod_review) { create(:vod_review, organization: other_organization) }

  describe 'GET /api/v1/vod-reviews/:vod_review_id/timestamps' do
    let!(:timestamps) { create_list(:vod_timestamp, 3, vod_review: vod_review) }

    context 'when authenticated' do
      it 'returns all timestamps for the vod review' do
        get "/api/v1/vod-reviews/#{vod_review.id}/timestamps", headers: auth_headers(user)

        expect(response).to have_http_status(:success)
        expect(json_response[:data][:timestamps].size).to eq(3)
      end

      it 'filters by category' do
        mistake = create(:vod_timestamp, :mistake, vod_review: vod_review)

        get "/api/v1/vod-reviews/#{vod_review.id}/timestamps",
            params: { category: 'mistake' },
            headers: auth_headers(user)

        expect(response).to have_http_status(:success)
        expect(json_response[:data][:timestamps].size).to eq(1)
      end

      it 'filters by importance' do
        critical = create(:vod_timestamp, :critical, vod_review: vod_review)

        get "/api/v1/vod-reviews/#{vod_review.id}/timestamps",
            params: { importance: 'critical' },
            headers: auth_headers(user)

        expect(response).to have_http_status(:success)
        expect(json_response[:data][:timestamps].size).to eq(1)
      end
    end

    context 'when accessing another organization vod review' do
      it 'returns forbidden' do
        get "/api/v1/vod-reviews/#{other_vod_review.id}/timestamps", headers: auth_headers(user)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get "/api/v1/vod-reviews/#{vod_review.id}/timestamps"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/vod-reviews/:vod_review_id/timestamps' do
    let(:player) { create(:player, organization: organization) }
    let(:valid_attributes) do
      {
        vod_timestamp: {
          timestamp_seconds: 120,
          title: 'Important moment',
          description: 'Description here',
          category: 'mistake',
          importance: 'high',
          target_type: 'player',
          target_player_id: player.id
        }
      }
    end

    context 'when authenticated' do
      it 'creates a new timestamp' do
        expect {
          post "/api/v1/vod-reviews/#{vod_review.id}/timestamps",
               params: valid_attributes.to_json,
               headers: auth_headers(user)
        }.to change(VodTimestamp, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response[:data][:timestamp][:title]).to eq('Important moment')
        expect(json_response[:data][:timestamp][:created_by][:id]).to eq(user.id)
      end

      it 'returns validation errors for invalid data' do
        invalid_attributes = { vod_timestamp: { title: '' } }

        post "/api/v1/vod-reviews/#{vod_review.id}/timestamps",
             params: invalid_attributes.to_json,
             headers: auth_headers(user)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('VALIDATION_ERROR')
      end
    end

    context 'when accessing another organization vod review' do
      it 'returns forbidden' do
        post "/api/v1/vod-reviews/#{other_vod_review.id}/timestamps",
             params: valid_attributes.to_json,
             headers: auth_headers(user)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PATCH /api/v1/vod-timestamps/:id' do
    let(:timestamp) { create(:vod_timestamp, vod_review: vod_review) }

    context 'when authenticated' do
      it 'updates the timestamp' do
        patch "/api/v1/vod-timestamps/#{timestamp.id}",
              params: { vod_timestamp: { title: 'Updated Title' } }.to_json,
              headers: auth_headers(user)

        expect(response).to have_http_status(:success)
        expect(json_response[:data][:timestamp][:title]).to eq('Updated Title')
      end

      it 'returns validation errors for invalid data' do
        patch "/api/v1/vod-timestamps/#{timestamp.id}",
              params: { vod_timestamp: { title: '' } }.to_json,
              headers: auth_headers(user)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when accessing another organization timestamp' do
      let(:other_timestamp) { create(:vod_timestamp, vod_review: other_vod_review) }

      it 'returns forbidden' do
        patch "/api/v1/vod-timestamps/#{other_timestamp.id}",
              params: { vod_timestamp: { title: 'Hacked' } }.to_json,
              headers: auth_headers(user)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'DELETE /api/v1/vod-timestamps/:id' do
    let!(:timestamp) { create(:vod_timestamp, vod_review: vod_review) }

    context 'when authenticated as analyst' do
      it 'deletes the timestamp' do
        expect {
          delete "/api/v1/vod-timestamps/#{timestamp.id}", headers: auth_headers(user)
        }.to change(VodTimestamp, :count).by(-1)

        expect(response).to have_http_status(:success)
      end
    end

    context 'when accessing another organization timestamp' do
      let(:other_timestamp) { create(:vod_timestamp, vod_review: other_vod_review) }

      it 'returns forbidden' do
        delete "/api/v1/vod-timestamps/#{other_timestamp.id}", headers: auth_headers(user)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
