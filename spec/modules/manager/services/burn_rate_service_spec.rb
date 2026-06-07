# frozen_string_literal: true

require 'rails_helper'

# Tests for Manager::BurnRateService (expense aggregation / burn rate).
#
# NOTE: the salary_period normalization (monthly × 1, weekly × 4, per_event → 0)
# lives in Manager::SalarySummaryService, which is tested below in a nested
# describe block. Both services are in the same module; testing them here avoids
# an extra file for a closely related concern.
RSpec.describe Manager::BurnRateService do
  let(:organization) { create(:organization) }
  let(:user)         { create(:user, :admin, organization: organization) }

  let(:this_month_from) { Date.current.beginning_of_month }
  let(:this_month_to)   { Date.current.end_of_month }

  def create_expense(category:, amount:, status: 'paid', date: Date.current)
    create(:expense,
           organization: organization,
           created_by: user,
           category: category,
           amount: amount,
           status: status,
           expense_date: date)
  end

  describe '#call' do
    context 'with no expenses in the period' do
      it 'returns zero for total_spent' do
        result = described_class.new(organization).call
        expect(result[:total_spent]).to eq(0)
      end

      it 'returns the correct period boundaries' do
        result = described_class.new(organization).call
        expect(result[:period][:from]).to eq(this_month_from)
        expect(result[:period][:to]).to eq(this_month_to)
      end

      it 'returns by_category with all categories present' do
        result = described_class.new(organization).call
        Expense::CATEGORIES.each do |cat|
          expect(result[:by_category]).to have_key(cat)
        end
      end

      it 'returns zero for pending_approval when no pending expenses exist' do
        result = described_class.new(organization).call
        expect(result[:pending_approval]).to eq(0)
      end
    end

    context 'when only paid expenses exist in the period' do
      before do
        create_expense(category: 'travel', amount: 500)
        create_expense(category: 'salary', amount: 3000)
        create_expense(category: 'bonus',  amount: 1000)
      end

      it 'sums total_spent across all paid expenses' do
        result = described_class.new(organization).call
        expect(result[:total_spent]).to eq(4500)
      end

      it 'breaks down by_category correctly' do
        result = described_class.new(organization).call
        expect(result[:by_category]['travel']).to eq(500)
        expect(result[:by_category]['salary']).to eq(3000)
        expect(result[:by_category]['bonus']).to eq(1000)
      end

      it 'salary_total includes both salary and bonus categories' do
        result = described_class.new(organization).call
        expect(result[:salary_total]).to eq(4000)
      end

      it 'operational excludes salary and bonus categories' do
        result = described_class.new(organization).call
        expect(result[:operational]).to eq(500)
      end
    end

    context 'when pending expenses exist' do
      before do
        create_expense(category: 'travel', amount: 300, status: 'pending')
        create_expense(category: 'travel', amount: 700, status: 'paid')
      end

      it 'excludes pending expenses from total_spent' do
        result = described_class.new(organization).call
        expect(result[:total_spent]).to eq(700)
      end

      it 'includes pending expenses in pending_approval' do
        result = described_class.new(organization).call
        expect(result[:pending_approval]).to eq(300)
      end
    end

    context 'when expenses fall outside the requested period' do
      before do
        # Paid but last month — outside default this-month window
        create_expense(category: 'equipment', amount: 2000, date: Date.current - 2.months)
        create_expense(category: 'travel',    amount: 500)
      end

      it 'does not count expenses outside the period in total_spent' do
        result = described_class.new(organization).call
        expect(result[:total_spent]).to eq(500)
      end
    end

    context 'with a custom date range' do
      let(:from) { Date.current - 60.days }
      let(:to)   { Date.current - 30.days }

      before do
        create_expense(category: 'housing', amount: 1200, date: from + 10.days)
        create_expense(category: 'travel',  amount: 300)  # today — outside range
      end

      it 'respects the custom from/to parameters' do
        result = described_class.new(organization, from: from, to: to).call
        expect(result[:total_spent]).to eq(1200)
        expect(result[:period][:from]).to eq(from)
        expect(result[:period][:to]).to eq(to)
      end
    end

    context 'multi-tenancy: expenses from another org are not included' do
      let(:other_org)  { create(:organization) }
      let(:other_user) { create(:user, :admin, organization: other_org) }

      before do
        create(:expense,
               organization: other_org,
               created_by: other_user,
               category: 'travel',
               amount: 9999,
               status: 'paid',
               expense_date: Date.current)
        create_expense(category: 'travel', amount: 100)
      end

      it 'only counts expenses belonging to the given organization' do
        result = described_class.new(organization).call
        expect(result[:total_spent]).to eq(100)
      end
    end
  end
end

# Salary period normalization is in Manager::SalarySummaryService.
# It is tested here to keep all payroll-related assertions in one place.
RSpec.describe Manager::SalarySummaryService do
  let(:organization) { create(:organization) }
  let(:admin)        { create(:user, :admin, organization: organization) }

  # SalarySummaryService calls Contract.unscoped.includes(:player).
  # Player includes OrganizationScoped, which gates queries on Current.organization_id.
  # Without this, the includes(:player) returns nil for all associations.
  before { Current.organization_id = organization.id }
  after  { Current.reset }

  def create_active_contract(player:, salary:, period:)
    create(:contract, :active,
           organization: organization,
           player: player,
           created_by: admin,
           base_salary: salary,
           salary_period: period)
  end

  describe '#call' do
    context 'salary_period normalization to monthly equivalent' do
      let(:monthly_player) { create(:player, organization: organization) }
      let(:weekly_player)  { create(:player, organization: organization) }
      let(:event_player)   { create(:player, organization: organization) }

      before do
        create_active_contract(player: monthly_player, salary: 1000, period: 'monthly')
        create_active_contract(player: weekly_player,  salary: 500,  period: 'weekly')
        create_active_contract(player: event_player,   salary: 2000, period: 'per_event')
      end

      it 'counts monthly salary at face value' do
        result = described_class.new(organization).call
        monthly_entry = result[:players].find { |p| p[:player_id] == monthly_player.id }
        expect(monthly_entry[:monthly_equiv]).to eq(1000)
      end

      it 'multiplies weekly salary by 4 to get monthly equivalent' do
        result = described_class.new(organization).call
        weekly_entry = result[:players].find { |p| p[:player_id] == weekly_player.id }
        expect(weekly_entry[:monthly_equiv]).to eq(2000)
      end

      it 'contributes 0 for per_event contracts' do
        result = described_class.new(organization).call
        event_entry = result[:players].find { |p| p[:player_id] == event_player.id }
        expect(event_entry[:monthly_equiv]).to eq(0)
      end

      it 'total_monthly_payroll sums only monthly and weekly contributions' do
        result = described_class.new(organization).call
        # monthly: 1000 + weekly: 500*4=2000 + per_event: 0 = 3000
        expect(result[:total_monthly_payroll]).to eq(3000)
      end

      it 'player_count reflects all active contracts regardless of period' do
        result = described_class.new(organization).call
        expect(result[:player_count]).to eq(3)
      end
    end

    context 'with no active contracts' do
      it 'returns zero total_monthly_payroll' do
        result = described_class.new(organization).call
        expect(result[:total_monthly_payroll]).to eq(0)
      end

      it 'returns empty players list' do
        result = described_class.new(organization).call
        expect(result[:players]).to be_empty
      end
    end

    context 'multi-tenancy: contracts from another org are not counted' do
      let(:other_org)    { create(:organization) }
      let(:other_admin)  { create(:user, :admin, organization: other_org) }
      let(:other_player) { create(:player, organization: other_org) }

      before do
        create(:contract, :active,
               organization: other_org,
               player: other_player,
               created_by: other_admin,
               base_salary: 99_999,
               salary_period: 'monthly')
      end

      it 'does not include contracts from another organization' do
        result = described_class.new(organization).call
        expect(result[:total_monthly_payroll]).to eq(0)
        expect(result[:player_count]).to eq(0)
      end
    end

    context 'role is always a valid LoL role for each player entry' do
      let(:player) { create(:player, organization: organization, role: 'mid') }

      before do
        create_active_contract(player: player, salary: 5000, period: 'monthly')
      end

      it 'includes a valid role string for each player' do
        valid_roles = %w[top jungle mid adc support]
        result = described_class.new(organization).call
        result[:players].each do |entry|
          expect(valid_roles).to include(entry[:role])
        end
      end
    end
  end
end
