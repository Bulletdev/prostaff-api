# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScrimResultReminderJob, type: :job do
  let(:org_a) { create(:organization) }
  let(:org_b) { create(:organization) }

  describe '#perform' do
    context 'when there are no past accepted scrims' do
      it 'runs without error and creates no reports' do
        expect { described_class.new.perform }.not_to raise_error
        expect(ScrimResultReport.count).to eq(0)
      end
    end

    context 'initialize_pending_reports' do
      let(:scrim_request) do
        create(:scrim_request, :accepted,
               requesting_organization: org_a,
               target_organization: org_b,
               proposed_at: 2.hours.ago)
      end

      before { scrim_request }

      it 'creates two ScrimResultReport records (one per org) for past accepted scrims' do
        expect { described_class.new.perform }
          .to change(ScrimResultReport, :count).by(2)
      end

      it 'sets both reports to pending status' do
        described_class.new.perform

        ScrimResultReport.all.each do |report|
          expect(report.status).to eq('pending')
        end
      end

      it 'sets deadline_at to at least DEADLINE_DAYS from now' do
        described_class.new.perform

        ScrimResultReport.all.each do |report|
          expect(report.deadline_at).to be > Time.current
        end
      end

      it 'is idempotent — does not duplicate reports on second run' do
        described_class.new.perform
        expect { described_class.new.perform }.not_to change(ScrimResultReport, :count)
      end
    end

    context 'expire_overdue_reports' do
      let(:scrim_request) do
        create(:scrim_request, :accepted,
               requesting_organization: org_a,
               target_organization: org_b,
               proposed_at: 2.weeks.ago)
      end

      it 'marks overdue pending reports as expired' do
        report = ScrimResultReport.create!(
          scrim_request: scrim_request,
          organization: org_a,
          status: 'pending',
          deadline_at: 1.day.ago,
          attempt_count: 0
        )

        described_class.new.perform

        expect(report.reload.status).to eq('expired')
      end

      it 'does not expire reports whose deadline has not passed' do
        report = ScrimResultReport.create!(
          scrim_request: scrim_request,
          organization: org_a,
          status: 'pending',
          deadline_at: 2.days.from_now,
          attempt_count: 0
        )

        described_class.new.perform

        expect(report.reload.status).to eq('pending')
      end
    end

    context 'when an unexpected error occurs' do
      it 'logs the error and re-raises so Sidekiq can retry' do
        allow(ScrimRequest).to receive(:where).and_raise(StandardError, 'db explosion')

        expect(Rails.logger).to receive(:error).with(include('[ScrimResultReminderJob] Failed:'))

        expect { described_class.new.perform }.to raise_error(StandardError, 'db explosion')
      end
    end

    context 'job metadata' do
      it 'is enqueued on the default queue' do
        expect(described_class.queue_name).to eq('default')
      end
    end
  end
end
