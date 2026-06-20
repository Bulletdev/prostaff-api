# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VOD Reviews Analysis API', type: :request do
  let(:organization) { create(:organization) }
  let(:analyst) { create(:user, :analyst, organization: organization) }
  let(:viewer) { create(:user, :viewer, organization: organization) }
  let(:vod_review) { create(:vod_review, organization: organization) }

  describe 'POST /api/v1/vod-reviews/:id/analyze' do
    context 'when authenticated as analyst' do
      before do
        allow(VideoAiClient).to receive(:create_job).and_return({ job_id: 'ext-123' })
      end

      it 'returns 201 with job_id and pending status' do
        post "/api/v1/vod-reviews/#{vod_review.id}/analyze",
             headers: auth_headers(analyst)

        expect(response).to have_http_status(:created)
        expect(json_response[:data][:job_id]).to be_present
        expect(json_response[:data][:status]).to eq('pending')
      end

      it 'creates a VodAnalysisJob record' do
        expect do
          post "/api/v1/vod-reviews/#{vod_review.id}/analyze",
               headers: auth_headers(analyst)
        end.to change { VodAnalysisJob.count }.by(1)
      end

      it 'enqueues AnalyzeVodJob' do
        expect do
          post "/api/v1/vod-reviews/#{vod_review.id}/analyze",
               headers: auth_headers(analyst)
        end.to have_enqueued_job(AnalyzeVodJob)
      end
    end

    context 'when authenticated as viewer' do
      it 'returns forbidden' do
        post "/api/v1/vod-reviews/#{vod_review.id}/analyze",
             headers: auth_headers(viewer)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        post "/api/v1/vod-reviews/#{vod_review.id}/analyze"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/vod-reviews/:id/analyze/:job_id' do
    context 'when job is in pending state' do
      let(:job) { create(:vod_analysis_job, vod_review: vod_review, status: 'pending') }

      it 'returns 200 with current status and no timestamps' do
        get "/api/v1/vod-reviews/#{vod_review.id}/analyze/#{job.id}",
            headers: auth_headers(analyst)

        expect(response).to have_http_status(:ok)
        data = json_response[:data]
        expect(data[:job_id]).to eq(job.id)
        expect(data[:status]).to eq('pending')
        expect(data[:suggested_timestamps]).to be_nil
      end
    end

    context 'when job is in_progress with external_job_id' do
      let(:job) { create(:vod_analysis_job, :downloading, vod_review: vod_review) }

      before do
        allow(VideoAiClient).to receive(:get_job).with(job.external_job_id).and_return(
          { status: 'analyzing', progress: 55, suggested_timestamps: nil }
        )
      end

      it 'polls VideoAI and returns updated status' do
        get "/api/v1/vod-reviews/#{vod_review.id}/analyze/#{job.id}",
            headers: auth_headers(analyst)

        expect(response).to have_http_status(:ok)
        data = json_response[:data]
        expect(data[:status]).to eq('analyzing')
        expect(data[:progress]).to eq(55)
        expect(data[:suggested_timestamps]).to be_nil
      end
    end

    context 'when job is done' do
      let(:suggestions) do
        [
          { 'id' => "#{SecureRandom.uuid}-0", 'start_seconds' => 120, 'reason' => 'teamfight', 'confidence' => 0.9 }
        ]
      end
      let(:job) do
        create(:vod_analysis_job, :done, vod_review: vod_review, suggested_timestamps: suggestions)
      end

      it 'returns suggested_timestamps in the response' do
        get "/api/v1/vod-reviews/#{vod_review.id}/analyze/#{job.id}",
            headers: auth_headers(analyst)

        expect(response).to have_http_status(:ok)
        data = json_response[:data]
        expect(data[:status]).to eq('done')
        expect(data[:suggested_timestamps]).to be_present
        expect(data[:suggested_timestamps].length).to eq(1)
      end
    end

    context 'when job belongs to another review' do
      let(:other_review) { create(:vod_review, organization: organization) }
      let(:other_job) { create(:vod_analysis_job, vod_review: other_review) }

      it 'returns not found' do
        get "/api/v1/vod-reviews/#{vod_review.id}/analyze/#{other_job.id}",
            headers: auth_headers(analyst)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /api/v1/vod-reviews/:id/import_suggestions' do
    let(:job_id) { SecureRandom.uuid }
    let(:suggestion_id) { "#{job_id}-0" }
    let(:suggestions) do
      [
        {
          'id' => suggestion_id,
          'start_seconds' => 120,
          'end_seconds' => 135,
          'reason' => 'teamfight near dragon',
          'confidence' => 0.92
        },
        {
          'id' => "#{job_id}-1",
          'start_seconds' => 300,
          'end_seconds' => 320,
          'reason' => 'baron steal',
          'confidence' => 0.60
        }
      ]
    end
    let(:job) do
      create(:vod_analysis_job, :done,
             vod_review: vod_review,
             suggested_timestamps: suggestions)
    end

    context 'when authenticated as analyst with valid params' do
      it 'returns 201 with imported_count' do
        post "/api/v1/vod-reviews/#{vod_review.id}/import_suggestions",
             params: { job_id: job.id, suggestion_ids: [suggestion_id] }.to_json,
             headers: auth_headers(analyst)

        expect(response).to have_http_status(:created)
        data = json_response[:data]
        expect(data[:imported_count]).to eq(1)
        expect(data[:timestamps]).to be_present
        expect(data[:timestamps].length).to eq(1)
      end

      it 'creates VodTimestamp records' do
        expect do
          post "/api/v1/vod-reviews/#{vod_review.id}/import_suggestions",
               params: { job_id: job.id, suggestion_ids: [suggestion_id] }.to_json,
               headers: auth_headers(analyst)
        end.to change { VodTimestamp.count }.by(1)
      end

      it 'maps confidence >= 0.9 to critical importance' do
        post "/api/v1/vod-reviews/#{vod_review.id}/import_suggestions",
             params: { job_id: job.id, suggestion_ids: [suggestion_id] }.to_json,
             headers: auth_headers(analyst)

        timestamp = vod_review.vod_timestamps.last
        expect(timestamp.importance).to eq('critical')
      end

      it 'rounds decimal start_seconds instead of truncating' do
        # 120.7 should become 121, not 120 (to_f.round vs to_i)
        job_with_decimal = create(:vod_analysis_job, :done,
                                  vod_review: vod_review,
                                  suggested_timestamps: [{
                                    'id' => "#{SecureRandom.uuid}-0",
                                    'start_seconds' => 120.7,
                                    'reason' => 'scene_change',
                                    'confidence' => 0.8
                                  }])
        decimal_id = job_with_decimal.suggested_timestamps.first['id']

        post "/api/v1/vod-reviews/#{vod_review.id}/import_suggestions",
             params: { job_id: job_with_decimal.id, suggestion_ids: [decimal_id] }.to_json,
             headers: auth_headers(analyst)

        expect(response).to have_http_status(:created)
        expect(vod_review.vod_timestamps.last.timestamp_seconds).to eq(121)
      end

      it 'humanizes reason with + separator correctly' do
        # 'scene_change+audio_spike' should become 'Scene change e audio spike'
        job_with_combined = create(:vod_analysis_job, :done,
                                   vod_review: vod_review,
                                   suggested_timestamps: [{
                                     'id' => "#{SecureRandom.uuid}-0",
                                     'start_seconds' => 60,
                                     'reason' => 'scene_change+audio_spike',
                                     'confidence' => 0.85
                                   }])
        combined_id = job_with_combined.suggested_timestamps.first['id']

        post "/api/v1/vod-reviews/#{vod_review.id}/import_suggestions",
             params: { job_id: job_with_combined.id, suggestion_ids: [combined_id] }.to_json,
             headers: auth_headers(analyst)

        expect(response).to have_http_status(:created)
        expect(vod_review.vod_timestamps.last.title).to eq('Scene change e audio spike')
      end

      it 'maps confidence < 0.5 to low importance' do
        low_conf_job = create(:vod_analysis_job, :done,
                              vod_review: vod_review,
                              suggested_timestamps: [{
                                'id' => "#{SecureRandom.uuid}-0",
                                'start_seconds' => 45,
                                'reason' => 'audio_spike',
                                'confidence' => 0.3
                              }])
        low_id = low_conf_job.suggested_timestamps.first['id']

        post "/api/v1/vod-reviews/#{vod_review.id}/import_suggestions",
             params: { job_id: low_conf_job.id, suggestion_ids: [low_id] }.to_json,
             headers: auth_headers(analyst)

        expect(vod_review.vod_timestamps.last.importance).to eq('low')
      end

      it 'imports multiple suggestions at once' do
        all_ids = suggestions.map { |s| s['id'] }

        expect do
          post "/api/v1/vod-reviews/#{vod_review.id}/import_suggestions",
               params: { job_id: job.id, suggestion_ids: all_ids }.to_json,
               headers: auth_headers(analyst)
        end.to change { VodTimestamp.count }.by(2)

        expect(json_response[:data][:imported_count]).to eq(2)
      end
    end

    context 'when job is not done' do
      let(:pending_job) { create(:vod_analysis_job, vod_review: vod_review, status: 'analyzing') }

      it 'returns not found' do
        post "/api/v1/vod-reviews/#{vod_review.id}/import_suggestions",
             params: { job_id: pending_job.id, suggestion_ids: [] }.to_json,
             headers: auth_headers(analyst)

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when job_id param is missing' do
      it 'returns bad request' do
        post "/api/v1/vod-reviews/#{vod_review.id}/import_suggestions",
             params: { suggestion_ids: [] }.to_json,
             headers: auth_headers(analyst)

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when authenticated as viewer' do
      it 'returns forbidden' do
        post "/api/v1/vod-reviews/#{vod_review.id}/import_suggestions",
             params: { job_id: job.id, suggestion_ids: [suggestion_id] }.to_json,
             headers: auth_headers(viewer)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
