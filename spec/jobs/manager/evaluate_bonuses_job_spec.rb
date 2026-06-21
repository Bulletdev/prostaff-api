# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Manager::EvaluateBonusesJob, type: :job do
  subject(:job) { described_class.new }

  let(:org)      { create(:organization) }
  let(:player)   { create(:player, organization: org) }
  let(:user)     { create(:user, organization: org) }
  let(:contract) { create(:contract, :active, organization: org, player: player, created_by: user) }

  # Build a bonus that is within its evaluation window by default.
  def build_pending_bonus(overrides = {})
    create(:contract_bonus, {
      contract: contract,
      organization: org,
      status: 'pending',
      metric_key: 'kda_ratio',
      comparator: 'gte',
      threshold: 3.0,
      evaluation_window: 'custom',
      window_start: Date.current - 30.days,
      window_end: Date.current + 30.days
    }.merge(overrides))
  end

  describe '#perform' do
    context 'when the evaluation window is not active' do
      let!(:bonus) do
        build_pending_bonus(
          window_start: Date.current - 60.days,
          window_end: Date.current - 1.day
        )
      end

      it 'does not mark the bonus as achieved' do
        expect { job.perform }.not_to(change { bonus.reload.status })
      end
    end

    context 'when the resolved player is nil' do
      let!(:bonus) { build_pending_bonus }

      before do
        allow_any_instance_of(ContractBonus).to receive(:contract).and_return(nil)
      end

      it 'skips the bonus without raising' do
        expect { job.perform }.not_to raise_error
        expect(bonus.reload.status).to eq('pending')
      end
    end

    context 'when comparator is satisfied (gte)' do
      let!(:bonus) { build_pending_bonus(comparator: 'gte', threshold: 3.0) }

      before do
        allow_any_instance_of(Goals::MetricResolver).to receive(:resolve).and_return(4.5)
      end

      it 'marks the bonus as achieved' do
        job.perform
        expect(bonus.reload.status).to eq('achieved')
      end

      it 'sets achieved_at to today' do
        job.perform
        expect(bonus.reload.achieved_at).to eq(Date.current)
      end
    end

    context 'when comparator is not satisfied (gte)' do
      let!(:bonus) { build_pending_bonus(comparator: 'gte', threshold: 5.0) }

      before do
        allow_any_instance_of(Goals::MetricResolver).to receive(:resolve).and_return(2.0)
      end

      it 'leaves the bonus pending' do
        job.perform
        expect(bonus.reload.status).to eq('pending')
      end
    end

    context 'when comparator is satisfied (lte)' do
      let!(:bonus) { build_pending_bonus(comparator: 'lte', threshold: 2.0) }

      before do
        allow_any_instance_of(Goals::MetricResolver).to receive(:resolve).and_return(1.5)
      end

      it 'marks the bonus as achieved' do
        job.perform
        expect(bonus.reload.status).to eq('achieved')
      end
    end

    context 'when comparator is satisfied (eq)' do
      let!(:bonus) { build_pending_bonus(comparator: 'eq', threshold: 3.0) }

      before do
        allow_any_instance_of(Goals::MetricResolver).to receive(:resolve).and_return(3.0)
      end

      it 'marks the bonus as achieved' do
        job.perform
        expect(bonus.reload.status).to eq('achieved')
      end
    end

    context 'when the resolver returns nil' do
      let!(:bonus) { build_pending_bonus }

      before do
        allow_any_instance_of(Goals::MetricResolver).to receive(:resolve).and_return(nil)
      end

      it 'skips the bonus and does not change status' do
        job.perform
        expect(bonus.reload.status).to eq('pending')
      end
    end

    context 'when one bonus raises an error' do
      let!(:failing_bonus) { build_pending_bonus }
      let!(:passing_bonus) { build_pending_bonus(comparator: 'gte', threshold: 1.0) }

      before do
        call_count = 0
        allow_any_instance_of(Goals::MetricResolver).to receive(:resolve) do
          call_count += 1
          raise StandardError, 'db error' if call_count == 1

          5.0
        end
      end

      it 'continues evaluating remaining bonuses after an error' do
        job.perform
        expect(passing_bonus.reload.status).to eq('achieved')
      end

      it 'does not re-raise the error' do
        expect { job.perform }.not_to raise_error
      end
    end

    context 'job metadata' do
      it 'is configured for the default queue' do
        expect(described_class.sidekiq_options_hash['queue']).to eq('default')
      end
    end
  end

  describe '#comparator_satisfied?' do
    subject(:job_instance) { described_class.new }

    let(:bonus) { build(:contract_bonus, contract: contract, organization: org) }

    it 'returns true for gte when value >= threshold' do
      bonus.comparator = 'gte'
      bonus.threshold  = 3.0
      expect(job_instance.send(:comparator_satisfied?, bonus, 3.5)).to be true
    end

    it 'returns false for gte when value < threshold' do
      bonus.comparator = 'gte'
      bonus.threshold  = 3.0
      expect(job_instance.send(:comparator_satisfied?, bonus, 2.0)).to be false
    end

    it 'returns true for lte when value <= threshold' do
      bonus.comparator = 'lte'
      bonus.threshold  = 2.0
      expect(job_instance.send(:comparator_satisfied?, bonus, 1.8)).to be true
    end

    it 'returns false for lte when value > threshold' do
      bonus.comparator = 'lte'
      bonus.threshold  = 2.0
      expect(job_instance.send(:comparator_satisfied?, bonus, 2.5)).to be false
    end

    it 'returns true for eq when value == threshold' do
      bonus.comparator = 'eq'
      bonus.threshold  = 4.0
      expect(job_instance.send(:comparator_satisfied?, bonus, 4.0)).to be true
    end

    it 'returns false for unknown comparator' do
      bonus.comparator = 'gt'
      bonus.threshold  = 3.0
      expect(job_instance.send(:comparator_satisfied?, bonus, 5.0)).to be false
    end
  end
end
