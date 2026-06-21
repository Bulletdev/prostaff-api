# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/modules/team_goals/services/goals/metric_registry'

RSpec.describe Goals::MetricRegistry do
  describe '.valid?' do
    it 'returns true for known rails_analytics keys' do
      expect(described_class.valid?('kda_ratio')).to be true
      expect(described_class.valid?('cs_per_min')).to be true
      expect(described_class.valid?('win_rate')).to be true
    end

    it 'returns true for rank_snapshot keys' do
      expect(described_class.valid?('soloq_lp_total')).to be true
      expect(described_class.valid?('soloq_win_rate')).to be true
    end

    it 'returns true for scraper keys' do
      expect(described_class.valid?('pro_kda')).to be true
      expect(described_class.valid?('pro_dpm')).to be true
      expect(described_class.valid?('pro_gd15')).to be true
    end

    it 'returns true for manual keys' do
      expect(described_class.valid?('soloq_games_week')).to be true
      expect(described_class.valid?('vod_review_hours_week')).to be true
    end

    it 'returns false for unknown keys' do
      expect(described_class.valid?('nonexistent_metric')).to be false
      expect(described_class.valid?('')).to be false
    end

    it 'is case sensitive' do
      expect(described_class.valid?('KDA_RATIO')).to be false
      expect(described_class.valid?('Win_Rate')).to be false
    end
  end

  describe '.source_for' do
    it 'returns :rails_analytics for local match stats metrics' do
      expect(described_class.source_for('kda_ratio')).to eq(:rails_analytics)
      expect(described_class.source_for('cs_per_min')).to eq(:rails_analytics)
      expect(described_class.source_for('vision_score_per_min')).to eq(:rails_analytics)
      expect(described_class.source_for('kill_participation')).to eq(:rails_analytics)
    end

    it 'returns :rank_snapshot for soloQ metrics' do
      expect(described_class.source_for('soloq_lp_total')).to eq(:rank_snapshot)
      expect(described_class.source_for('soloq_win_rate')).to eq(:rank_snapshot)
    end

    it 'returns :scraper for professional match metrics' do
      expect(described_class.source_for('pro_kda')).to eq(:scraper)
      expect(described_class.source_for('pro_cs_per_min')).to eq(:scraper)
      expect(described_class.source_for('pro_dpm')).to eq(:scraper)
      expect(described_class.source_for('pro_gd15')).to eq(:scraper)
      expect(described_class.source_for('pro_wpm')).to eq(:scraper)
    end

    it 'returns :manual for activity metrics' do
      expect(described_class.source_for('soloq_games_week')).to eq(:manual)
      expect(described_class.source_for('vod_review_hours_week')).to eq(:manual)
      expect(described_class.source_for('practice_sessions_week')).to eq(:manual)
    end

    it 'returns nil for unknown keys' do
      expect(described_class.source_for('nonexistent')).to be_nil
    end
  end

  describe '.manual?' do
    it 'returns true only for the three manual metrics' do
      expect(described_class.manual?('soloq_games_week')).to be true
      expect(described_class.manual?('vod_review_hours_week')).to be true
      expect(described_class.manual?('practice_sessions_week')).to be true
    end

    it 'returns false for auto-resolved metrics' do
      expect(described_class.manual?('kda_ratio')).to be false
      expect(described_class.manual?('soloq_lp_total')).to be false
      expect(described_class.manual?('pro_kda')).to be false
    end

    it 'returns false for unknown keys' do
      expect(described_class.manual?('nonexistent')).to be false
    end
  end

  describe 'METRICS constant' do
    it 'covers all four valid sources' do
      sources = described_class::METRICS.values.map { |v| v[:source] }.uniq
      expect(sources).to match_array(described_class::VALID_SOURCES)
    end

    it 'has exactly three manual metrics' do
      manual_keys = described_class::METRICS.select { |_, v| v[:source] == :manual }.keys
      expect(manual_keys).to match_array(%w[soloq_games_week vod_review_hours_week practice_sessions_week])
    end

    it 'declares a unit for every metric' do
      described_class::METRICS.each do |key, meta|
        expect(meta[:unit]).not_to be_nil, "#{key} is missing a unit declaration"
      end
    end
  end
end
