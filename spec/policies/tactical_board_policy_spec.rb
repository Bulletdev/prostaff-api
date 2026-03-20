# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TacticalBoardPolicy, type: :policy do
  subject { described_class.new(user, tactical_board) }

  let(:organization) { create(:organization) }
  let(:tactical_board) { create(:tactical_board, organization: organization) }

  context 'for an owner' do
    let(:user) { create(:user, :owner, organization: organization) }

    it { should permit_action(:index) }
    it { should permit_action(:show) }
    it { should permit_action(:create) }
    it { should permit_action(:update) }
    it { should permit_action(:destroy) }
    it { should permit_action(:statistics) }
  end

  context 'for an admin' do
    let(:user) { create(:user, :admin, organization: organization) }

    it { should permit_action(:index) }
    it { should permit_action(:show) }
    it { should permit_action(:create) }
    it { should permit_action(:update) }
    it { should permit_action(:destroy) }
    it { should permit_action(:statistics) }
  end

  context 'for a coach' do
    let(:user) { create(:user, :coach, organization: organization) }

    it { should permit_action(:index) }
    it { should permit_action(:show) }
    it { should permit_action(:create) }
    it { should permit_action(:update) }
    it { should_not permit_action(:destroy) }
    it { should permit_action(:statistics) }
  end

  context 'for a viewer' do
    let(:user) { create(:user, :viewer, organization: organization) }

    it { should_not permit_action(:index) }
    it { should_not permit_action(:show) }
    it { should_not permit_action(:create) }
    it { should_not permit_action(:update) }
    it { should_not permit_action(:destroy) }
    it { should_not permit_action(:statistics) }
  end

  context 'for a user from different organization' do
    let(:other_org) { create(:organization) }
    let(:user) { create(:user, :coach, organization: other_org) }

    it { should_not permit_action(:show) }
    it { should_not permit_action(:update) }
    it { should_not permit_action(:destroy) }
    it { should_not permit_action(:statistics) }
  end

  describe 'Scope' do
    let(:user) { create(:user, :coach, organization: organization) }
    let(:other_org) { create(:organization) }
    let!(:other_board) { create(:tactical_board, organization: other_org) }

    it 'returns only tactical boards for the user organization' do
      scope = described_class::Scope.new(user, TacticalBoard.unscoped).resolve
      expect(scope).to include(tactical_board)
      expect(scope).not_to include(other_board)
    end

    context 'for a viewer' do
      let(:user) { create(:user, :viewer, organization: organization) }

      it 'returns no tactical boards' do
        scope = described_class::Scope.new(user, TacticalBoard.unscoped).resolve
        expect(scope).to be_empty
      end
    end
  end
end
