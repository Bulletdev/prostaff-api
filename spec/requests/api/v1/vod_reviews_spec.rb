# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VOD Reviews API', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :analyst, organization: organization) }
  let(:admin) { create(:user, :admin, organization: organization) }
  let(:other_organization) { create(:organization) }
  let(:other_user) { create(:user, organization: other_organization) }

  describe 'GET /api/v1/vod-reviews' do
    let!(:vod_reviews) { create_list(:vod_review, 3, organization: organization) }

    context 'when authenticated' do
      it 'returns all vod reviews for the organization' do
        get '/api/v1/vod-reviews', headers: auth_headers(user)

        expect(response).to have_http_status(:success)
        expect(json_response[:data][:vod_reviews].size).to eq(3)
      end

      it 'filters by status' do
        create(:vod_review, :published, organization: organization)

        get '/api/v1/vod-reviews', params: { status: 'published' }, headers: auth_headers(user)

        expect(response).to have_http_status(:success)
        expect(json_response[:data][:vod_reviews].size).to eq(1)
      end

      it 'filters by match_id' do
        match = create(:match, organization: organization)
        create(:vod_review, match: match, organization: organization)

        get '/api/v1/vod-reviews', params: { match_id: match.id }, headers: auth_headers(user)

        expect(response).to have_http_status(:success)
        expect(json_response[:data][:vod_reviews].size).to eq(1)
      end

      it 'includes pagination metadata' do
        get '/api/v1/vod-reviews', headers: auth_headers(user)

        expect(response).to have_http_status(:success)
        expect(json_response[:data][:pagination]).to include(
          :current_page,
          :per_page,
          :total_pages,
          :total_count
        )
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get '/api/v1/vod-reviews'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/vod-reviews/:id' do
    let(:vod_review) { create(:vod_review, :with_timestamps, organization: organization) }

    context 'when authenticated' do
      it 'returns the vod review with timestamps' do
        get "/api/v1/vod-reviews/#{vod_review.id}", headers: auth_headers(user)

        expect(response).to have_http_status(:success)
        expect(json_response[:data][:vod_review][:id]).to eq(vod_review.id)
        expect(json_response[:data][:timestamps]).to be_present
      end
    end

    context 'when accessing another organization vod review' do
      let(:other_vod_review) { create(:vod_review, organization: other_organization) }

      # OrganizationScoped default_scope makes cross-org records invisible (404, not 403)
      it 'returns not found' do
        get "/api/v1/vod-reviews/#{other_vod_review.id}", headers: auth_headers(user)

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when vod review not found' do
      it 'returns not found' do
        get '/api/v1/vod-reviews/00000000-0000-0000-0000-000000000000', headers: auth_headers(user)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /api/v1/vod-reviews' do
    let(:valid_attributes) do
      {
        vod_review: {
          title: 'Test VOD Review',
          description: 'Test description',
          video_url: 'https://www.youtube.com/watch?v=abc123',
          review_type: 'team',
          status: 'draft'
        }
      }
    end

    context 'when authenticated as analyst' do
      it 'creates a new vod review' do
        expect do
          post '/api/v1/vod-reviews',
               params: valid_attributes.to_json,
               headers: auth_headers(user)
        end.to change { VodReview.unscoped.count }.by(1)

        expect(response).to have_http_status(:created)
        expect(json_response[:data][:vod_review][:title]).to eq('Test VOD Review')
        expect(json_response[:data][:vod_review][:reviewer][:id]).to eq(user.id)
      end

      it 'returns validation errors for invalid data' do
        invalid_attributes = { vod_review: { title: '' } }

        post '/api/v1/vod-reviews',
             params: invalid_attributes.to_json,
             headers: auth_headers(user)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('VALIDATION_ERROR')
      end
    end
  end

  describe 'POST /api/v1/vod-reviews (multi_pov)' do
    let(:multi_pov_attributes) do
      {
        vod_review: {
          title: 'Multi-POV Scrim Review',
          description: 'Three camera angles',
          video_url: 'https://www.youtube.com/watch?v=anchor000',
          review_type: 'multi_pov',
          status: 'draft',
          video_urls: [
            'https://www.youtube.com/watch?v=pov1aaaaaaa',
            'https://www.youtube.com/watch?v=pov2bbbbbbb'
          ],
          video_labels: ['Top Lane POV', 'Mid Lane POV']
        }
      }
    end

    context 'when authenticated as analyst' do
      it 'creates a multi-pov review with 2 valid URLs' do
        expect do
          post '/api/v1/vod-reviews',
               params: multi_pov_attributes.to_json,
               headers: auth_headers(user)
        end.to change { VodReview.unscoped.count }.by(1)

        expect(response).to have_http_status(:created)
        data = json_response[:data][:vod_review]
        expect(data[:review_type]).to eq('multi_pov')
        expect(data[:video_urls].size).to eq(2)
        expect(data[:video_labels]).to eq(['Top Lane POV', 'Mid Lane POV'])
      end

      it 'returns 422 for multi_pov with only 1 URL' do
        attrs = {
          vod_review: {
            title: 'Bad Multi-POV',
            video_url: 'https://www.youtube.com/watch?v=anchor000',
            review_type: 'multi_pov',
            status: 'draft',
            video_urls: ['https://www.youtube.com/watch?v=pov1aaaaaaa']
          }
        }

        post '/api/v1/vod-reviews',
             params: attrs.to_json,
             headers: auth_headers(user)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('VALIDATION_ERROR')
        details = json_response[:error][:details]
        expect(details[:video_urls].to_s).to include('must have between 2 and 4 URLs')
      end
    end
  end

  describe 'PATCH /api/v1/vod-reviews/:id' do
    let(:vod_review) { create(:vod_review, organization: organization) }

    context 'when authenticated' do
      it 'updates the vod review' do
        patch "/api/v1/vod-reviews/#{vod_review.id}",
              params: { vod_review: { title: 'Updated Title' } }.to_json,
              headers: auth_headers(user)

        expect(response).to have_http_status(:success)
        expect(json_response[:data][:vod_review][:title]).to eq('Updated Title')
      end

      it 'returns validation errors for invalid data' do
        patch "/api/v1/vod-reviews/#{vod_review.id}",
              params: { vod_review: { title: '' } }.to_json,
              headers: auth_headers(user)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when accessing another organization vod review' do
      let(:other_vod_review) { create(:vod_review, organization: other_organization) }

      # OrganizationScoped default_scope makes cross-org records invisible (404, not 403)
      it 'returns not found' do
        patch "/api/v1/vod-reviews/#{other_vod_review.id}",
              params: { vod_review: { title: 'Hacked' } }.to_json,
              headers: auth_headers(user)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET /api/v1/vod-reviews/:id/player' do
    let(:vod_review) { create(:vod_review, :with_timestamps, organization: organization) }

    context 'when authenticated' do
      it 'returns 200 with review data and ordered timestamps' do
        get "/api/v1/vod-reviews/#{vod_review.id}/player", headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        data = json_response[:data]
        expect(data[:vod_review][:id]).to eq(vod_review.id)
        expect(data[:timestamps]).to be_an(Array)
        expect(data[:timestamps].size).to eq(3)
      end

      it 'returns timestamps ordered by timestamp_seconds' do
        review = create(:vod_review, organization: organization)
        create(:vod_timestamp, vod_review: review, timestamp_seconds: 300)
        create(:vod_timestamp, vod_review: review, timestamp_seconds: 60)
        create(:vod_timestamp, vod_review: review, timestamp_seconds: 180)

        get "/api/v1/vod-reviews/#{review.id}/player", headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        seconds = json_response[:data][:timestamps].map { |t| t[:timestamp_seconds] }
        expect(seconds).to eq([60, 180, 300])
      end

      it 'includes video_provider in the review data' do
        review = create(:vod_review, organization: organization,
                                     video_url: 'https://www.youtube.com/watch?v=test')

        get "/api/v1/vod-reviews/#{review.id}/player", headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:vod_review][:video_provider]).to eq('youtube')
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get "/api/v1/vod-reviews/#{vod_review.id}/player"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when the review belongs to another organization' do
      let(:other_vod_review) { create(:vod_review, organization: other_organization) }

      it 'returns not found' do
        get "/api/v1/vod-reviews/#{other_vod_review.id}/player", headers: auth_headers(user)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'DELETE /api/v1/vod-reviews/:id' do
    let!(:vod_review) { create(:vod_review, organization: organization) }

    context 'when authenticated as admin' do
      it 'deletes the vod review' do
        expect do
          delete "/api/v1/vod-reviews/#{vod_review.id}", headers: auth_headers(admin)
        end.to change { VodReview.unscoped.count }.by(-1)

        expect(response).to have_http_status(:success)
      end
    end

    context 'when authenticated as analyst' do
      it 'returns forbidden' do
        delete "/api/v1/vod-reviews/#{vod_review.id}", headers: auth_headers(user)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
