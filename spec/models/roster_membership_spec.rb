# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RosterMembership, type: :model do
  let(:org)    { create(:organization) }
  let(:player) { create(:player, organization: org) }

  subject(:membership) { build(:roster_membership, organization: org, player: player) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(membership).to be_valid
    end

    it 'is invalid without a role' do
      membership.role = nil
      expect(membership).not_to be_valid
    end

    it 'is invalid with an unrecognized role' do
      membership.role = 'carry'
      expect(membership).not_to be_valid
      expect(membership.errors[:role]).to be_present
    end

    it 'is valid with each known role' do
      RosterMembership::ROLES.each do |r|
        m = build(:roster_membership, organization: org, player: player, role: r)
        expect(m).to be_valid, "Expected role '#{r}' to be valid"
      end
    end

    it 'is invalid without a status' do
      membership.status = nil
      expect(membership).not_to be_valid
    end

    it 'is invalid with an unrecognized status' do
      membership.status = 'benched'
      expect(membership).not_to be_valid
      expect(membership.errors[:status]).to be_present
    end

    it 'is valid with each known status' do
      RosterMembership::STATUSES.each do |s|
        m = build(:roster_membership, organization: org, player: player, status: s)
        expect(m).to be_valid, "Expected status '#{s}' to be valid"
      end
    end

    it 'is invalid without a joined_at date' do
      membership.joined_at = nil
      expect(membership).not_to be_valid
      expect(membership.errors[:joined_at]).to be_present
    end

    it 'is invalid with an unrecognized line' do
      membership.line = 'challenger_series'
      expect(membership).not_to be_valid
      expect(membership.errors[:line]).to be_present
    end

    it 'is valid with each known line' do
      RosterMembership::LINES.each do |l|
        m = build(:roster_membership, organization: org, player: player, line: l)
        expect(m).to be_valid, "Expected line '#{l}' to be valid"
      end
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to belong_to(:player) }
    it { is_expected.to belong_to(:contract).optional }
    it { is_expected.to belong_to(:created_by).optional }
  end

  describe 'scopes' do
    describe '.active' do
      let!(:active_membership) do
        create(:roster_membership, :active, organization: org, player: player)
      end
      let!(:ended_membership) do
        create(:roster_membership, :inactive, organization: org, player: player)
      end
      let!(:deleted_membership) do
        create(:roster_membership, :active, organization: org, player: player,
                                            deleted_at: Time.current)
      end

      it 'returns memberships with left_at nil and deleted_at nil' do
        expect(RosterMembership.active).to include(active_membership)
      end

      it 'excludes memberships with left_at set' do
        expect(RosterMembership.active).not_to include(ended_membership)
      end

      it 'excludes soft-deleted memberships' do
        expect(RosterMembership.active).not_to include(deleted_membership)
      end
    end

    describe '.historical' do
      let!(:current_member) do
        create(:roster_membership, :active, organization: org, player: player)
      end
      let!(:former_member) do
        create(:roster_membership, :inactive, organization: org, player: player)
      end

      it 'returns memberships with a left_at date set' do
        expect(RosterMembership.historical).to include(former_member)
      end

      it 'excludes currently active memberships' do
        expect(RosterMembership.historical).not_to include(current_member)
      end
    end

    describe '.not_deleted' do
      let!(:live)    { create(:roster_membership, :active, organization: org, player: player) }
      let!(:deleted) do
        create(:roster_membership, :active, organization: org, player: player,
                                            deleted_at: Time.current)
      end

      it 'excludes soft-deleted records' do
        expect(RosterMembership.not_deleted).to include(live)
        expect(RosterMembership.not_deleted).not_to include(deleted)
      end
    end
  end

  describe '#soft_delete!' do
    let(:membership) { create(:roster_membership, :active) }

    it 'sets deleted_at' do
      expect { membership.soft_delete! }.to(change { membership.reload.deleted_at }.from(nil))
    end

    it 'sets left_at when not already set' do
      expect { membership.soft_delete! }.to(change { membership.reload.left_at }.from(nil))
    end

    it 'does not overwrite an existing left_at' do
      membership.update!(left_at: Date.current - 5.days)
      membership.soft_delete!
      expect(membership.reload.left_at).to eq(Date.current - 5.days)
    end
  end

  describe '#deleted?' do
    it 'returns false when deleted_at is nil' do
      membership.deleted_at = nil
      expect(membership.deleted?).to be false
    end

    it 'returns true when deleted_at is set' do
      membership.deleted_at = Time.current
      expect(membership.deleted?).to be true
    end
  end
end
