# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Manager::ExpensePolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:creator)      { create(:user, :admin, organization: organization) }

  let(:pending_expense) do
    create(:expense, organization: organization, created_by: creator, status: 'pending')
  end

  let(:paid_expense) do
    create(:expense, :paid, organization: organization, created_by: creator)
  end

  # ── owner ─────────────────────────────────────────────────────────────────

  context 'for an owner' do
    let(:user) { create(:user, :owner, organization: organization) }

    subject { described_class.new(user, pending_expense) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to permit_action(:destroy) }
    it { is_expected.to permit_action(:approve) }
    it { is_expected.to permit_action(:mark_paid) }
    it { is_expected.to permit_action(:reject) }
    it { is_expected.to permit_action(:salary_summary) }
    it { is_expected.to permit_action(:report) }
    it { is_expected.to permit_action(:export) }

    context 'with a paid expense' do
      subject { described_class.new(user, paid_expense) }

      it 'cannot update a paid expense' do
        is_expected.not_to permit_action(:update)
      end

      it 'cannot destroy a paid expense' do
        is_expected.not_to permit_action(:destroy)
      end
    end
  end

  # ── admin ─────────────────────────────────────────────────────────────────

  context 'for an admin' do
    let(:user) { create(:user, :admin, organization: organization) }

    subject { described_class.new(user, pending_expense) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to permit_action(:destroy) }
    it { is_expected.to permit_action(:approve) }
    it { is_expected.to permit_action(:mark_paid) }
    it { is_expected.to permit_action(:reject) }
    it { is_expected.to permit_action(:salary_summary) }
    it { is_expected.to permit_action(:report) }
    it { is_expected.to permit_action(:export) }

    context 'with a paid expense' do
      subject { described_class.new(user, paid_expense) }

      it 'cannot update a paid expense' do
        is_expected.not_to permit_action(:update)
      end

      it 'cannot destroy a paid expense' do
        is_expected.not_to permit_action(:destroy)
      end
    end
  end

  # ── manager ───────────────────────────────────────────────────────────────

  context 'for a manager' do
    let(:user) { create(:user, :manager, organization: organization) }

    subject { described_class.new(user, pending_expense) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to permit_action(:destroy) }
    it { is_expected.to permit_action(:approve) }
    it { is_expected.to permit_action(:mark_paid) }
    it { is_expected.to permit_action(:reject) }
    it { is_expected.to permit_action(:salary_summary) }

    context 'with a paid expense' do
      subject { described_class.new(user, paid_expense) }

      it 'cannot update a paid expense' do
        is_expected.not_to permit_action(:update)
      end

      it 'cannot destroy a paid expense' do
        is_expected.not_to permit_action(:destroy)
      end
    end
  end

  # ── coach ─────────────────────────────────────────────────────────────────

  context 'for a coach' do
    let(:user) { create(:user, :coach, organization: organization) }

    subject { described_class.new(user, pending_expense) }

    it { is_expected.not_to permit_action(:index) }
    it { is_expected.not_to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.not_to permit_action(:approve) }
    it { is_expected.not_to permit_action(:mark_paid) }
    it { is_expected.not_to permit_action(:reject) }
    it { is_expected.not_to permit_action(:salary_summary) }
    it { is_expected.not_to permit_action(:report) }
    it { is_expected.not_to permit_action(:export) }
  end

  # ── analyst ───────────────────────────────────────────────────────────────

  context 'for an analyst' do
    let(:user) { create(:user, :analyst, organization: organization) }

    subject { described_class.new(user, pending_expense) }

    it { is_expected.not_to permit_action(:index) }
    it { is_expected.not_to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.not_to permit_action(:approve) }
    it { is_expected.not_to permit_action(:mark_paid) }
    it { is_expected.not_to permit_action(:reject) }
    it { is_expected.not_to permit_action(:salary_summary) }
    it { is_expected.not_to permit_action(:report) }
    it { is_expected.not_to permit_action(:export) }
  end

  # ── viewer ────────────────────────────────────────────────────────────────

  context 'for a viewer' do
    let(:user) { create(:user, :viewer, organization: organization) }

    subject { described_class.new(user, pending_expense) }

    it { is_expected.not_to permit_action(:index) }
    it { is_expected.not_to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.not_to permit_action(:approve) }
    it { is_expected.not_to permit_action(:mark_paid) }
    it { is_expected.not_to permit_action(:reject) }
    it { is_expected.not_to permit_action(:salary_summary) }
    it { is_expected.not_to permit_action(:report) }
    it { is_expected.not_to permit_action(:export) }
  end
end
