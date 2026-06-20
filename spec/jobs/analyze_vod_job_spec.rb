# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AnalyzeVodJob, type: :job do
  let(:vod_review) { create(:vod_review) }
  let(:analysis_job) { create(:vod_analysis_job, vod_review: vod_review, status: 'pending') }

  describe '#perform' do
    context 'when VideoAI responds successfully' do
      before do
        allow(VideoAiClient).to receive(:create_job).and_return(
          { job_id: 'ext-abc-123' }
        )
      end

      it 'transitions through queued then downloading' do
        described_class.perform_now(analysis_job.id)

        analysis_job.reload
        expect(analysis_job.status).to eq('downloading')
        expect(analysis_job.external_job_id).to eq('ext-abc-123')
      end

      it 'calls VideoAiClient with correct params' do
        described_class.perform_now(analysis_job.id)

        expect(VideoAiClient).to have_received(:create_job).with(
          vod_review_id: vod_review.id,
          video_url: vod_review.video_url
        )
      end
    end

    context 'when the job is already done' do
      let(:done_job) { create(:vod_analysis_job, :done, vod_review: vod_review) }

      it 'skips execution silently' do
        allow(VideoAiClient).to receive(:create_job)

        described_class.perform_now(done_job.id)

        expect(VideoAiClient).not_to have_received(:create_job)
        done_job.reload
        expect(done_job.status).to eq('done')
      end
    end

    context 'when the job is already failed' do
      let(:failed_job) { create(:vod_analysis_job, :failed, vod_review: vod_review) }

      it 'skips execution silently' do
        allow(VideoAiClient).to receive(:create_job)

        described_class.perform_now(failed_job.id)

        expect(VideoAiClient).not_to have_received(:create_job)
      end
    end

    context 'when VideoAI returns an error' do
      before do
        allow(VideoAiClient).to receive(:create_job)
          .and_raise(VideoAiClient::Error, 'VideoAI returned 503')
      end

      it 'marks the job as failed with error_message' do
        described_class.perform_now(analysis_job.id)

        analysis_job.reload
        expect(analysis_job.status).to eq('failed')
        expect(analysis_job.error_message).to eq('VideoAI returned 503')
      end

      it 'does not raise an exception' do
        expect { described_class.perform_now(analysis_job.id) }.not_to raise_error
      end
    end

    context 'when an unexpected error occurs' do
      before do
        allow(VideoAiClient).to receive(:create_job)
          .and_raise(StandardError, 'Unexpected failure')
      end

      it 'marks the job as failed' do
        described_class.perform_now(analysis_job.id)

        analysis_job.reload
        expect(analysis_job.status).to eq('failed')
        expect(analysis_job.error_message).to eq('Unexpected failure')
      end

      it 'does not raise an exception' do
        expect { described_class.perform_now(analysis_job.id) }.not_to raise_error
      end
    end
  end
end
