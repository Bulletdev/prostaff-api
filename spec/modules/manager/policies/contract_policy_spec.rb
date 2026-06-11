# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Manager::ContractPolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:player)       { create(:player, organization: organization) }

  # draft contract — editable and destroyable
  let(:draft_contract) do
    admin = create(:user, :admin, organization: organization)
    create(:contract, :draft, organization: organization, player: player, created_by: admin)
  end

  # active contract — neither editable nor destroyable
  let(:active_contract) do
    admin = create(:user, :admin, organization: organization)
    create(:contract, :active, organization: organization, player: player, created_by: admin)
  end

  # ── owner ─────────────────────────────────────────────────────────────────

  context 'for an owner' do
    let(:user) { create(:user, :owner, organization: organization) }

    subject { described_class.new(user, draft_contract) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to permit_action(:destroy) }
    it { is_expected.to permit_action(:activate) }
    it { is_expected.to permit_action(:terminate) }
    it { is_expected.to permit_action(:renew) }
    it { is_expected.to permit_action(:expiring) }
    it { is_expected.to permit_action(:dashboard) }

    context 'with an active contract' do
      subject { described_class.new(user, active_contract) }

      it 'cannot update an active contract' do
        is_expected.not_to permit_action(:update)
      end

      it 'cannot destroy an active contract' do
        is_expected.not_to permit_action(:destroy)
      end
    end
  end

  # ── admin ─────────────────────────────────────────────────────────────────

  context 'for an admin' do
    let(:user) { create(:user, :admin, organization: organization) }

    subject { described_class.new(user, draft_contract) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to permit_action(:destroy) }
    it { is_expected.to permit_action(:activate) }
    it { is_expected.to permit_action(:terminate) }
    it { is_expected.to permit_action(:renew) }

    context 'with an active contract' do
      subject { described_class.new(user, active_contract) }

      it 'cannot update an active contract' do
        is_expected.not_to permit_action(:update)
      end

      it 'cannot destroy an active contract' do
        is_expected.not_to permit_action(:destroy)
      end
    end
  end

  # ── manager ───────────────────────────────────────────────────────────────

  context 'for a manager' do
    let(:user) { create(:user, :manager, organization: organization) }

    subject { described_class.new(user, draft_contract) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to permit_action(:destroy) }
    it { is_expected.to permit_action(:activate) }
    it { is_expected.to permit_action(:terminate) }
    it { is_expected.to permit_action(:renew) }

    context 'with an active contract' do
      subject { described_class.new(user, active_contract) }

      it 'cannot update an active contract' do
        is_expected.not_to permit_action(:update)
      end

      it 'cannot destroy an active contract' do
        is_expected.not_to permit_action(:destroy)
      end
    end
  end

  # ── coach ─────────────────────────────────────────────────────────────────

  context 'for a coach' do
    let(:user) { create(:user, :coach, organization: organization) }

    # show? has special logic: coach can view if contract is a player contract
    context 'viewing a player contract (show?)' do
      subject { described_class.new(user, draft_contract) }

      it 'can show a player contract' do
        is_expected.to permit_action(:show)
      end

      it 'cannot index contracts' do
        is_expected.not_to permit_action(:index)
      end

      it 'cannot create contracts' do
        is_expected.not_to permit_action(:create)
      end

      it 'cannot update contracts' do
        is_expected.not_to permit_action(:update)
      end

      it 'cannot destroy contracts' do
        is_expected.not_to permit_action(:destroy)
      end

      it 'cannot activate contracts' do
        is_expected.not_to permit_action(:activate)
      end

      it 'cannot terminate contracts' do
        is_expected.not_to permit_action(:terminate)
      end
    end
  end

  # ── analyst ───────────────────────────────────────────────────────────────

  context 'for an analyst' do
    let(:user) { create(:user, :analyst, organization: organization) }

    subject { described_class.new(user, draft_contract) }

    it { is_expected.not_to permit_action(:index) }
    it { is_expected.not_to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.not_to permit_action(:activate) }
    it { is_expected.not_to permit_action(:terminate) }
    it { is_expected.not_to permit_action(:renew) }
    it { is_expected.not_to permit_action(:expiring) }
    it { is_expected.not_to permit_action(:dashboard) }
  end

  # ── viewer ────────────────────────────────────────────────────────────────

  context 'for a viewer' do
    let(:user) { create(:user, :viewer, organization: organization) }

    subject { described_class.new(user, draft_contract) }

    it { is_expected.not_to permit_action(:index) }
    it { is_expected.not_to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
    it { is_expected.not_to permit_action(:activate) }
    it { is_expected.not_to permit_action(:terminate) }
    it { is_expected.not_to permit_action(:renew) }
  end

  # ── cross-org isolation (policy layer) ───────────────────────────────────
  #
  # ContractPolicy action predicates (update?, destroy?, etc.) are role-based only —
  # they do NOT check organization membership. Cross-org isolation is enforced at the
  # controller layer by scoping the record lookup through current_organization.
  # A manager from another org cannot receive the record at all via the controller.
  #
  # These tests document the intended boundary: coach/analyst/viewer cannot act,
  # regardless of organization.

  context 'for a coach from a different organization (no financial access)' do
    let(:other_org)  { create(:organization) }
    let(:other_user) { create(:user, :coach, organization: other_org) }

    subject { described_class.new(other_user, draft_contract) }

    it 'coach from another org cannot index contracts' do
      is_expected.not_to permit_action(:index)
    end

    it 'coach from another org cannot create contracts' do
      is_expected.not_to permit_action(:create)
    end

    it 'coach from another org cannot update contracts' do
      is_expected.not_to permit_action(:update)
    end

    it 'coach from another org cannot destroy contracts' do
      is_expected.not_to permit_action(:destroy)
    end
  end

  context 'for an analyst from a different organization' do
    let(:other_org)  { create(:organization) }
    let(:other_user) { create(:user, :analyst, organization: other_org) }

    subject { described_class.new(other_user, draft_contract) }

    it 'analyst from another org cannot index contracts' do
      is_expected.not_to permit_action(:index)
    end

    it 'analyst from another org cannot create contracts' do
      is_expected.not_to permit_action(:create)
    end
  end
end
