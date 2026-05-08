# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TeamGoal, type: :model do
  let(:org)  { create(:organization) }

  describe 'associations' do
    it { should belong_to(:organization) }
    it { should belong_to(:player).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:start_date) }
    it { should validate_presence_of(:end_date) }
    it { should validate_numericality_of(:progress).is_in(0..100) }

    it 'is invalid when end_date is before start_date' do
      goal = build(:team_goal, organization: org, start_date: Date.current, end_date: Date.current - 1.day)
      expect(goal).not_to be_valid
      expect(goal.errors[:end_date]).to be_present
    end

    it 'is invalid when end_date equals start_date' do
      goal = build(:team_goal, organization: org, start_date: Date.current, end_date: Date.current)
      expect(goal).not_to be_valid
    end
  end

  describe '#days_remaining' do
    it 'returns 0 when end_date is in the past' do
      goal = build(:team_goal, organization: org, start_date: 10.days.ago.to_date, end_date: 1.day.ago.to_date)
      expect(goal.days_remaining).to eq(0)
    end

    it 'returns positive days when end_date is in the future' do
      goal = build(:team_goal, organization: org, start_date: Date.current, end_date: Date.current + 7.days)
      expect(goal.days_remaining).to be_between(1, 7)
    end
  end

  describe '#is_overdue?' do
    it 'returns true when past end_date and still active' do
      goal = create(:team_goal, organization: org,
                                start_date: 20.days.ago.to_date,
                                end_date: 10.days.ago.to_date,
                                status: 'active')
      expect(goal.is_overdue?).to be true
    end

    it 'returns false when completed' do
      goal = create(:team_goal, :completed, organization: org,
                                            start_date: 20.days.ago.to_date,
                                            end_date: 10.days.ago.to_date)
      expect(goal.is_overdue?).to be false
    end
  end

  describe '#completion_percentage' do
    it 'returns 0 when target_value is nil' do
      goal = build(:team_goal, organization: org, target_value: nil, current_value: nil)
      expect(goal.completion_percentage).to eq(0)
    end

    it 'caps at 100 when current exceeds target' do
      goal = build(:team_goal, organization: org, target_value: 50.0, current_value: 80.0)
      expect(goal.completion_percentage).to eq(100)
    end

    it 'calculates correctly' do
      goal = build(:team_goal, organization: org, target_value: 100.0, current_value: 65.0)
      expect(goal.completion_percentage).to eq(65.0)
    end
  end

  describe '#mark_as_completed!' do
    let(:goal) { create(:team_goal, organization: org) }

    it 'sets status to completed and progress to 100' do
      goal.mark_as_completed!
      expect(goal.reload.status).to eq('completed')
      expect(goal.reload.progress).to eq(100)
    end
  end

  describe '#is_team_goal? and #is_player_goal?' do
    it 'is a team goal when player is nil' do
      goal = build(:team_goal, organization: org)
      expect(goal.is_team_goal?).to be true
      expect(goal.is_player_goal?).to be false
    end

    it 'is a player goal when player is assigned' do
      player = create(:player, organization: org)
      goal   = build(:team_goal, :for_player, organization: org, player: player)
      expect(goal.is_player_goal?).to be true
      expect(goal.is_team_goal?).to be false
    end
  end

  describe '.metrics_for_role' do
    it 'returns win_rate for every role' do
      %w[top jungle mid adc support].each do |role|
        expect(described_class.metrics_for_role(role)).to include('win_rate')
      end
    end

    it 'returns vision_score for support role' do
      expect(described_class.metrics_for_role('support')).to include('vision_score')
    end
  end
end
