# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Goals::EvaluateGoalsJob, type: :job do
  subject(:job) { described_class.new }

  let(:org)    { create(:organization) }
  let(:player) { create(:player, organization: org) }

  describe '#perform' do
    context 'when a goal is evaluable and resolver returns a value' do
      let!(:goal) do
        create(:team_goal, :evaluable, organization: org, player: player,
                                       target_value: 60.0, comparator: 'gte')
      end

      before do
        allow_any_instance_of(Goals::MetricResolver)
          .to receive(:resolve).and_return(65.0)
      end

      it 'creates a GoalCheckIn with source auto' do
        expect { job.perform }.to change(GoalCheckIn, :count).by(1)
        expect(GoalCheckIn.last.source).to eq('auto')
        expect(GoalCheckIn.last.measured_value).to eq(65.0)
      end

      it 'updates current_value on the goal' do
        job.perform
        expect(goal.reload.current_value.to_f).to eq(65.0)
      end

      it 'sets status to met when comparator is satisfied' do
        job.perform
        expect(goal.reload.status).to eq('met')
      end
    end

    context 'when value does not meet target yet' do
      let!(:goal) do
        create(:team_goal, :evaluable, organization: org, player: player,
                                       target_value: 70.0, comparator: 'gte',
                                       due_date: Date.current + 20.days)
      end

      before do
        allow_any_instance_of(Goals::MetricResolver)
          .to receive(:resolve).and_return(55.0)
      end

      it 'sets status to on_track when due_date is > 7 days away' do
        job.perform
        expect(goal.reload.status).to eq('on_track')
      end
    end

    context 'when due_date is within 7 days and target not met' do
      let!(:goal) do
        create(:team_goal, :evaluable, organization: org, player: player,
                                       target_value: 70.0, comparator: 'gte',
                                       due_date: Date.current + 3.days)
      end

      before do
        allow_any_instance_of(Goals::MetricResolver)
          .to receive(:resolve).and_return(55.0)
      end

      it 'sets status to at_risk' do
        job.perform
        expect(goal.reload.status).to eq('at_risk')
      end
    end

    context 'when due_date has passed and target not met' do
      let!(:goal) do
        create(:team_goal, :evaluable, organization: org, player: player,
                                       target_value: 70.0, comparator: 'gte',
                                       due_date: Date.current - 1.day)
      end

      before do
        allow_any_instance_of(Goals::MetricResolver)
          .to receive(:resolve).and_return(55.0)
      end

      it 'sets status to missed' do
        job.perform
        expect(goal.reload.status).to eq('missed')
      end
    end

    context 'when lte comparator is used' do
      let!(:goal) do
        create(:team_goal, :evaluable, organization: org, player: player,
                                       target_value: 3.0, comparator: 'lte',
                                       metric_key: 'kda_ratio')
      end

      before do
        allow_any_instance_of(Goals::MetricResolver)
          .to receive(:resolve).and_return(2.5)
      end

      it 'sets status to met when value is below target' do
        job.perform
        expect(goal.reload.status).to eq('met')
      end
    end

    context 'when resolver returns nil' do
      let!(:goal) { create(:team_goal, :evaluable, organization: org, player: player) }

      before do
        allow_any_instance_of(Goals::MetricResolver)
          .to receive(:resolve).and_return(nil)
      end

      it 'does not create a check-in' do
        expect { job.perform }.not_to change(GoalCheckIn, :count)
      end

      it 'does not change goal status' do
        expect { job.perform }.not_to(change { goal.reload.status })
      end
    end

    context 'when a goal is terminal (met)' do
      let!(:goal) do
        create(:team_goal, :evaluable, organization: org, player: player,
                                       status: 'met')
      end

      before do
        allow_any_instance_of(Goals::MetricResolver)
          .to receive(:resolve).and_return(75.0)
      end

      it 'skips terminal goals' do
        expect { job.perform }.not_to change(GoalCheckIn, :count)
      end
    end

    context 'when a goal has no metric_key' do
      let!(:goal) do
        create(:team_goal, organization: org, player: player,
                           metric_key: nil, assignable_type: 'Player')
      end

      it 'skips goals without metric_key' do
        expect { job.perform }.not_to change(GoalCheckIn, :count)
      end
    end

    context 'when one goal raises an error' do
      let!(:goal1) { create(:team_goal, :evaluable, organization: org, player: player) }
      let!(:goal2) { create(:team_goal, :evaluable, organization: org, player: player) }

      before do
        call_count = 0
        allow_any_instance_of(Goals::MetricResolver).to receive(:resolve) do
          call_count += 1
          raise StandardError, 'Network failure' if call_count == 1

          65.0
        end
      end

      it 'continues evaluating remaining goals' do
        expect { job.perform }.to change(GoalCheckIn, :count).by(1)
      end
    end
  end

  describe 'status computation helpers' do
    subject(:job_instance) { described_class.new }

    let(:goal) do
      build(:team_goal, target_value: 60.0, comparator: 'gte',
                        due_date: Date.current + 20.days)
    end

    it 'returns met when gte comparator satisfied' do
      result = job_instance.send(:compute_status, goal, 65.0)
      expect(result).to eq('met')
    end

    it 'returns on_track when not met and due is > 7 days' do
      result = job_instance.send(:compute_status, goal, 50.0)
      expect(result).to eq('on_track')
    end

    it 'returns at_risk when not met and due is <= 7 days' do
      goal.due_date = Date.current + 5.days
      result = job_instance.send(:compute_status, goal, 50.0)
      expect(result).to eq('at_risk')
    end

    it 'returns missed when due_date is in the past' do
      goal.due_date = Date.current - 1.day
      result = job_instance.send(:compute_status, goal, 50.0)
      expect(result).to eq('missed')
    end

    it 'defaults to gte when comparator is nil' do
      goal.comparator = nil
      expect(job_instance.send(:comparator_satisfied?, goal, 65.0)).to be true
    end
  end
end
