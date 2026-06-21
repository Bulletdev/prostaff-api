# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Manager::ContractRenewalService do
  let(:organization) { create(:organization) }
  let(:user)         { create(:user, :admin, organization: organization) }
  let(:player)       { create(:player, organization: organization) }

  let(:renewal_params) do
    {
      start_date:  Date.current + 1.year + 1.day,
      end_date:    Date.current + 2.years,
      base_salary: 7500.00
    }
  end

  # Helper — creates an active player contract and immediately moves it to a
  # status that allows a new draft to be created for the same player.
  # (The overlap validation blocks a second draft while one already exists.)
  def create_active_player_contract(overrides = {})
    create(:contract, :active,
           organization: organization,
           player: player,
           created_by: user,
           **overrides)
  end

  describe '#call — player contract' do
    let!(:original) { create_active_player_contract(end_date: Date.current + 1.year) }

    subject(:renewal) { described_class.new(original, renewal_params, user).call }

    it 'returns the newly created contract' do
      expect(renewal).to be_a(Contract)
    end

    it 'creates the renewal with status draft' do
      expect(renewal.status).to eq('draft')
    end

    it 'links the renewal to the original via renewed_from_id' do
      expect(renewal.renewed_from_id).to eq(original.id)
    end

    it 'inherits contract_type from the original' do
      expect(renewal.contract_type).to eq(original.contract_type)
    end

    it 'inherits player_id from the original' do
      expect(renewal.player_id).to eq(original.player_id)
    end

    it 'inherits organization_id from the original' do
      expect(renewal.organization_id).to eq(original.organization_id)
    end

    it 'sets start_date from renewal_params' do
      expect(renewal.start_date).to eq(renewal_params[:start_date])
    end

    it 'sets end_date from renewal_params' do
      expect(renewal.end_date).to eq(renewal_params[:end_date])
    end

    it 'sets base_salary from renewal_params' do
      expect(renewal.base_salary).to eq(renewal_params[:base_salary])
    end

    it 'marks the original contract as renewed' do
      renewal
      expect(original.reload.status).to eq('renewed')
    end

    it 'sets created_by to the acting user on the renewal' do
      expect(renewal.created_by).to eq(user)
    end

    it 'increments the total contract count by 1' do
      expect { renewal }.to change { Contract.unscoped.count }.by(1)
    end

    context 'when no base_salary is supplied in params' do
      let(:renewal_params) do
        {
          start_date: Date.current + 1.year + 1.day,
          end_date:   Date.current + 2.years
        }
      end

      it 'falls back to the original base_salary' do
        expect(renewal.base_salary).to eq(original.base_salary)
      end
    end

    context 'when salary_period is supplied in params' do
      let(:renewal_params) do
        {
          start_date:    Date.current + 1.year + 1.day,
          end_date:      Date.current + 2.years,
          salary_period: 'weekly'
        }
      end

      it 'uses the supplied salary_period' do
        expect(renewal.salary_period).to eq('weekly')
      end
    end

    context 'when salary_period is absent from params' do
      it 'inherits salary_period from the original' do
        expect(renewal.salary_period).to eq(original.salary_period)
      end
    end
  end

  # ── Transaction atomicity ───────────────────────────────────────────────────
  #
  # If Contract.create! fails (e.g. invalid dates), the original must NOT be
  # left in 'renewed' status.

  describe 'transaction rollback on failure' do
    let!(:original) { create_active_player_contract(end_date: Date.current + 1.year) }

    let(:bad_params) do
      # end_date before start_date triggers the end_date_after_start_date validation
      {
        start_date:  Date.current + 2.years,
        end_date:    Date.current + 1.year,
        base_salary: 5000.00
      }
    end

    it 'raises an ActiveRecord error' do
      expect do
        described_class.new(original, bad_params, user).call
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'does not change the original contract status' do
      begin
        described_class.new(original, bad_params, user).call
      rescue ActiveRecord::RecordInvalid
        nil
      end

      expect(original.reload.status).to eq('active')
    end

    it 'does not create a new contract record' do
      expect do
        begin
          described_class.new(original, bad_params, user).call
        rescue ActiveRecord::RecordInvalid
          nil
        end
      end.not_to change { Contract.unscoped.count }
    end
  end

  # ── Staff contract renewal ──────────────────────────────────────────────────

  describe '#call — staff contract' do
    let(:staff_member) do
      create(:staff_member,
             organization: organization,
             name: 'Head Coach Silva',
             role: 'head_coach',
             status: 'active')
    end

    let!(:staff_contract) do
      create(:contract,
             organization: organization,
             contract_type: 'staff',
             player: nil,
             staff_member: staff_member,
             created_by: user,
             status: 'active',
             start_date: Date.current,
             end_date: Date.current + 1.year,
             base_salary: 8000.00)
    end

    let(:renewal_params) do
      {
        start_date:  Date.current + 1.year + 1.day,
        end_date:    Date.current + 2.years,
        base_salary: 9000.00
      }
    end

    subject(:renewal) { described_class.new(staff_contract, renewal_params, user).call }

    it 'creates a new draft contract' do
      expect { renewal }.to change { Contract.unscoped.count }.by(1)
    end

    it 'copies staff_member_id to the renewed contract' do
      expect(renewal.staff_member_id).to eq(staff_member.id)
    end

    it 'marks the original as renewed' do
      renewal
      expect(staff_contract.reload.status).to eq('renewed')
    end

    it 'sets renewed_from_id on the new contract' do
      expect(renewal.renewed_from_id).to eq(staff_contract.id)
    end

    it 'applies the new base_salary from params' do
      expect(renewal.base_salary).to eq(9000.00)
    end
  end
end
