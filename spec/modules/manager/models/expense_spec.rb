# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Expense, type: :model do
  let(:organization) { create(:organization) }
  let(:user)         { create(:user, organization: organization) }

  def build_expense(*traits, **overrides)
    build(:expense, *traits, organization: organization, created_by: user, **overrides)
  end

  def create_expense(*traits, **overrides)
    create(:expense, *traits, organization: organization, created_by: user, **overrides)
  end

  # ── Validations ─────────────────────────────────────────────────────────────

  describe 'validations' do
    describe 'category' do
      it 'is valid for every allowed category' do
        Expense::CATEGORIES.each do |cat|
          expense = build_expense(category: cat)
          expect(expense).to be_valid, "expected category '#{cat}' to be valid"
        end
      end

      it 'is invalid for an unrecognised category' do
        expense = build_expense(category: 'marketing')
        expect(expense).not_to be_valid
        expect(expense.errors[:category]).to be_present
      end
    end

    describe 'amount' do
      it 'is invalid when amount is zero' do
        expense = build_expense(amount: 0)
        expect(expense).not_to be_valid
        expect(expense.errors[:amount]).to be_present
      end

      it 'is invalid when amount is negative' do
        expense = build_expense(amount: -100)
        expect(expense).not_to be_valid
        expect(expense.errors[:amount]).to be_present
      end

      it 'is valid for a positive amount' do
        expense = build_expense(amount: 0.01)
        expect(expense).to be_valid
      end
    end

    describe 'expense_date' do
      it 'is invalid without expense_date' do
        expense = build_expense(expense_date: nil)
        expect(expense).not_to be_valid
        expect(expense.errors[:expense_date]).to be_present
      end
    end

    describe 'description' do
      it 'is invalid without description' do
        expense = build_expense(description: nil)
        expect(expense).not_to be_valid
        expect(expense.errors[:description]).to be_present
      end
    end

    describe 'status' do
      it 'is invalid for an unknown status' do
        expense = build_expense(status: 'archived')
        expect(expense).not_to be_valid
        expect(expense.errors[:status]).to be_present
      end
    end
  end

  # ── Scopes ───────────────────────────────────────────────────────────────────

  describe '.by_category scope' do
    it 'returns only expenses matching the given category' do
      travel_expense   = create_expense(category: 'travel')
      bootcamp_expense = create_expense(category: 'bootcamp')

      results = Expense.by_category('travel')
      expect(results).to include(travel_expense)
      expect(results).not_to include(bootcamp_expense)
    end
  end

  describe '.paid scope' do
    it 'returns only expenses with status paid' do
      paid_expense    = create_expense(:paid)
      pending_expense = create_expense(status: 'pending')

      expect(Expense.paid).to include(paid_expense)
      expect(Expense.paid).not_to include(pending_expense)
    end
  end

  describe '.pending scope' do
    it 'returns only expenses with status pending' do
      pending_expense = create_expense(status: 'pending')
      approved        = create_expense(:approved)

      expect(Expense.pending).to include(pending_expense)
      expect(Expense.pending).not_to include(approved)
    end
  end

  describe '.salary scope' do
    it 'returns only expenses in the salary category' do
      salary_expense = create_expense(:salary)
      other_expense  = create_expense(category: 'travel')

      expect(Expense.salary).to include(salary_expense)
      expect(Expense.salary).not_to include(other_expense)
    end
  end

  describe '.non_salary scope' do
    it 'excludes salary expenses' do
      salary_expense = create_expense(:salary)
      travel_expense = create_expense(category: 'travel')

      expect(Expense.non_salary).to include(travel_expense)
      expect(Expense.non_salary).not_to include(salary_expense)
    end
  end
end
