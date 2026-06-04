# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScrimResultReport, type: :model do
  let(:requesting_org) { create(:organization) }
  let(:target_org)     { create(:organization) }
  let(:scrim_request) do
    create(:scrim_request,
           requesting_organization: requesting_org,
           target_organization:     target_org)
  end

  describe 'associations' do
    it { is_expected.to belong_to(:scrim_request) }
    it { is_expected.to belong_to(:organization) }
  end

  describe 'validations' do
    subject { build(:scrim_result_report, scrim_request: scrim_request, organization: requesting_org) }

    it 'accepts all valid status values' do
      ScrimResultReport::STATUSES.each do |status|
        report = build(:scrim_result_report,
                       scrim_request: scrim_request,
                       organization: requesting_org,
                       status: status)
        report.game_outcomes = %w[win loss] if report.reported_at.present?
        expect(report).to be_valid, "expected status '#{status}' to be valid"
      end
    end

    it 'rejects invalid status values' do
      report = build(:scrim_result_report,
                     scrim_request: scrim_request,
                     organization: requesting_org,
                     status: 'invalid_status')
      expect(report).not_to be_valid
      expect(report.errors[:status]).to be_present
    end

    context 'when reported_at is set' do
      it 'requires game_outcomes' do
        report = build(:scrim_result_report,
                       scrim_request: scrim_request,
                       organization: requesting_org,
                       status: 'reported',
                       reported_at: Time.current,
                       game_outcomes: [])
        expect(report).not_to be_valid
        expect(report.errors[:game_outcomes]).to be_present
      end

      it 'rejects invalid outcome values' do
        report = build(:scrim_result_report,
                       scrim_request: scrim_request,
                       organization: requesting_org,
                       status: 'reported',
                       reported_at: Time.current,
                       game_outcomes: %w[win draw])
        expect(report).not_to be_valid
        expect(report.errors[:game_outcomes]).to be_present
      end

      it 'accepts only win/loss values' do
        report = build(:scrim_result_report,
                       scrim_request: scrim_request,
                       organization: requesting_org,
                       status: 'reported',
                       reported_at: Time.current,
                       game_outcomes: %w[win loss win])
        expect(report).to be_valid
      end
    end
  end

  describe '#re_reportable?' do
    it 'returns true when status is disputed and under MAX_ATTEMPTS' do
      report = build(:scrim_result_report, :disputed,
                     scrim_request: scrim_request,
                     organization: requesting_org)
      expect(report.re_reportable?).to be(true)
    end

    it 'returns false when status is confirmed' do
      report = build(:scrim_result_report, :confirmed,
                     scrim_request: scrim_request,
                     organization: requesting_org)
      expect(report.re_reportable?).to be(false)
    end

    it 'returns false when attempt_count reaches MAX_ATTEMPTS' do
      report = build(:scrim_result_report,
                     scrim_request: scrim_request,
                     organization: requesting_org,
                     status: 'disputed',
                     attempt_count: ScrimResultReport::MAX_ATTEMPTS)
      expect(report.re_reportable?).to be(false)
    end
  end

  describe '#attempts_remaining' do
    it 'returns MAX_ATTEMPTS minus current attempt_count' do
      report = build(:scrim_result_report,
                     scrim_request: scrim_request,
                     organization: requesting_org,
                     attempt_count: 1)
      expect(report.attempts_remaining).to eq(ScrimResultReport::MAX_ATTEMPTS - 1)
    end
  end

  describe '#series_winner_org_id' do
    context 'when status is confirmed' do
      it 'returns reporting org when wins exceed losses' do
        report = create(:scrim_result_report, :confirmed,
                        scrim_request: scrim_request,
                        organization: requesting_org)
        # Factory has game_outcomes: %w[win win loss] — 2 wins, 1 loss for requesting org
        expect(report.series_winner_org_id).to eq(requesting_org.id)
      end
    end

    context 'when status is not confirmed' do
      it 'returns nil' do
        report = build(:scrim_result_report,
                       scrim_request: scrim_request,
                       organization: requesting_org,
                       status: 'pending')
        expect(report.series_winner_org_id).to be_nil
      end
    end
  end

  describe 'scopes' do
    let!(:pending_report)  { create(:scrim_result_report, scrim_request: scrim_request, organization: requesting_org) }
    let!(:confirmed_report) do
      create(:scrim_result_report, :confirmed,
             scrim_request: create(:scrim_request, requesting_organization: requesting_org, target_organization: target_org),
             organization: requesting_org)
    end

    describe '.actionable' do
      it 'includes pending reports' do
        expect(ScrimResultReport.actionable).to include(pending_report)
      end

      it 'excludes confirmed reports' do
        expect(ScrimResultReport.actionable).not_to include(confirmed_report)
      end
    end

    describe '.confirmed' do
      it 'returns only confirmed reports' do
        expect(ScrimResultReport.confirmed).to include(confirmed_report)
        expect(ScrimResultReport.confirmed).not_to include(pending_report)
      end
    end
  end

  describe 'constants' do
    it 'defines MAX_ATTEMPTS as 3' do
      expect(ScrimResultReport::MAX_ATTEMPTS).to eq(3)
    end

    it 'defines DEADLINE_DAYS as 7' do
      expect(ScrimResultReport::DEADLINE_DAYS).to eq(7)
    end

    it 'defines all expected statuses' do
      expected = %w[pending reported confirmed disputed unresolvable expired]
      expect(ScrimResultReport::STATUSES).to match_array(expected)
    end
  end
end
