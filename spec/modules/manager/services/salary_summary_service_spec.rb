# frozen_string_literal: true

require 'rails_helper'

# SalarySummaryService reads from Contract.unscoped + Player.unscoped. Both
# models honour Current.organization_id for scoped associations (used internally
# via includes). We set it before each example and reset after.
RSpec.describe Manager::SalarySummaryService do
  let(:organization) { create(:organization) }
  let(:admin)        { create(:user, :admin, organization: organization) }

  before { Current.organization_id = organization.id }
  after  { Current.reset }

  def create_active_contract(player:, salary:, period:, end_date: Date.current + 1.year)
    create(:contract, :active,
           organization: organization,
           player:        player,
           created_by:    admin,
           base_salary:   salary,
           salary_period: period,
           end_date:      end_date)
  end

  # ── Salary period normalization ─────────────────────────────────────────────

  describe 'salary period normalization' do
    let(:monthly_player) { create(:player, organization: organization, role: 'top') }
    let(:weekly_player)  { create(:player, organization: organization, role: 'jungle') }
    let(:event_player)   { create(:player, organization: organization, role: 'mid') }

    before do
      create_active_contract(player: monthly_player, salary: 1000, period: 'monthly')
      create_active_contract(player: weekly_player,  salary: 500,  period: 'weekly')
      create_active_contract(player: event_player,   salary: 2000, period: 'per_event')
    end

    subject(:result) { described_class.new(organization).call }

    it 'counts monthly salary at face value (x1)' do
      entry = result[:players].find { |p| p[:player_id] == monthly_player.id }
      expect(entry[:monthly_equiv]).to eq(1000)
    end

    it 'multiplies weekly salary by 4 for monthly equivalent' do
      entry = result[:players].find { |p| p[:player_id] == weekly_player.id }
      expect(entry[:monthly_equiv]).to eq(2000)
    end

    it 'assigns 0 monthly_equiv to per_event contracts' do
      entry = result[:players].find { |p| p[:player_id] == event_player.id }
      expect(entry[:monthly_equiv]).to eq(0)
    end

    it 'total_monthly_payroll sums monthly and weekly only (excludes per_event)' do
      # monthly: 1000 + weekly: 500*4=2000 + per_event: 0 = 3000
      expect(result[:total_monthly_payroll]).to eq(3000)
    end

    it 'player_count reflects all active contracts regardless of period' do
      expect(result[:player_count]).to eq(3)
    end
  end

  # ── total_monthly_payroll ───────────────────────────────────────────────────

  describe '#call total_monthly_payroll' do
    context 'with no contracts at all' do
      it 'returns 0' do
        expect(described_class.new(organization).call[:total_monthly_payroll]).to eq(0)
      end
    end

    context 'with a single monthly contract' do
      before do
        player = create(:player, organization: organization)
        create_active_contract(player: player, salary: 5000, period: 'monthly')
      end

      it 'equals the contract base_salary' do
        expect(described_class.new(organization).call[:total_monthly_payroll]).to eq(5000)
      end
    end

    context 'with multiple monthly contracts' do
      before do
        p1 = create(:player, organization: organization)
        p2 = create(:player, organization: organization)
        create_active_contract(player: p1, salary: 3000, period: 'monthly')
        create_active_contract(player: p2, salary: 2000, period: 'monthly')
      end

      it 'sums all monthly salaries' do
        expect(described_class.new(organization).call[:total_monthly_payroll]).to eq(5000)
      end
    end
  end

  # ── player_count ─────────────────────────────────────────────────────────────

  describe '#call player_count' do
    context 'with no active contracts' do
      it 'returns 0' do
        expect(described_class.new(organization).call[:player_count]).to eq(0)
      end
    end

    context 'only non-active contracts exist (draft, expired, terminated)' do
      let(:player_a) { create(:player, organization: organization) }
      let(:player_b) { create(:player, organization: organization) }

      before do
        create(:contract, organization: organization, player: player_a,
               created_by: admin, status: 'draft',
               start_date: Date.current, end_date: Date.current + 1.year,
               base_salary: 1000, salary_period: 'monthly')
        create(:contract, organization: organization, player: player_b,
               created_by: admin, status: 'expired',
               start_date: 2.years.ago, end_date: 1.year.ago,
               base_salary: 1000, salary_period: 'monthly')
      end

      it 'returns 0 — draft and expired contracts are excluded' do
        expect(described_class.new(organization).call[:player_count]).to eq(0)
      end
    end
  end

  # ── players array structure ──────────────────────────────────────────────────

  describe '#call players array' do
    let(:player) { create(:player, organization: organization, role: 'adc') }

    before do
      create_active_contract(
        player:   player,
        salary:   6000,
        period:   'monthly',
        end_date: Date.current + 90.days
      )
    end

    subject(:entry) { described_class.new(organization).call[:players].first }

    it 'includes player_id' do
      expect(entry[:player_id]).to eq(player.id)
    end

    it 'includes player_name (summoner_name)' do
      expect(entry[:player_name]).to eq(player.summoner_name)
    end

    it 'includes a valid LoL role' do
      expect(%w[top jungle mid adc support]).to include(entry[:role])
    end

    it 'includes salary' do
      expect(entry[:salary]).to eq(6000)
    end

    it 'includes monthly_equiv' do
      expect(entry[:monthly_equiv]).to eq(6000)
    end

    it 'includes currency' do
      expect(entry[:currency]).to be_present
    end

    it 'includes contract_ends date' do
      expect(entry[:contract_ends]).to be_a(Date)
    end

    it 'includes days_remaining as a non-negative integer' do
      expect(entry[:days_remaining]).to be >= 0
    end

    context 'with no contracts' do
      it 'returns an empty array' do
        result = described_class.new(create(:organization)).call
        expect(result[:players]).to eq([])
      end
    end
  end

  # ── Only active contracts included ───────────────────────────────────────────

  describe 'status filtering' do
    let(:active_player)     { create(:player, organization: organization) }
    let(:draft_player)      { create(:player, organization: organization) }
    let(:terminated_player) { create(:player, organization: organization) }

    before do
      create_active_contract(player: active_player, salary: 5000, period: 'monthly')

      create(:contract, organization: organization, player: draft_player,
             created_by: admin, status: 'draft',
             start_date: Date.current + 1.day, end_date: Date.current + 1.year,
             base_salary: 9999, salary_period: 'monthly')

      # terminated requires bypassing overlap validation — use update_columns
      terminated_contract = create_active_contract(
        player:   terminated_player,
        salary:   9999,
        period:   'monthly'
      )
      terminated_contract.update_columns(status: 'terminated')
    end

    subject(:result) { described_class.new(organization).call }

    it 'includes only the active player in the list' do
      ids = result[:players].map { |p| p[:player_id] }
      expect(ids).to include(active_player.id)
      expect(ids).not_to include(draft_player.id)
      expect(ids).not_to include(terminated_player.id)
    end

    it 'does not count draft or terminated contracts in total_monthly_payroll' do
      expect(result[:total_monthly_payroll]).to eq(5000)
    end
  end

  # ── Multi-tenancy isolation ──────────────────────────────────────────────────

  describe 'multi-tenancy: other organization contracts are excluded' do
    let(:other_org)    { create(:organization) }
    let(:other_admin)  { create(:user, :admin, organization: other_org) }
    let(:other_player) { create(:player, organization: other_org) }

    before do
      create(:contract, :active,
             organization:  other_org,
             player:        other_player,
             created_by:    other_admin,
             base_salary:   99_999,
             salary_period: 'monthly')
    end

    it 'does not include contracts from another organization in total_monthly_payroll' do
      result = described_class.new(organization).call
      expect(result[:total_monthly_payroll]).to eq(0)
    end

    it 'does not count players from another organization' do
      result = described_class.new(organization).call
      expect(result[:player_count]).to eq(0)
    end

    it 'does not expose another org player in the players array' do
      result = described_class.new(organization).call
      ids = result[:players].map { |p| p[:player_id] }
      expect(ids).not_to include(other_player.id)
    end
  end
end
