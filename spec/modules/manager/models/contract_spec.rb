# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Contract, type: :model do
  let(:organization) { create(:organization) }
  let(:user)         { create(:user, organization: organization) }
  let(:player)       { create(:player, organization: organization) }

  # Helper to build a minimal valid contract without hitting the
  # no_overlapping_active_contract validation on :create.
  # traits: optional FactoryBot trait symbols, e.g. :active, :draft
  def build_contract(*traits, **overrides)
    build(:contract, *traits,
          organization: organization,
          player: player,
          created_by: user,
          **overrides)
  end

  def create_contract(*traits, **overrides)
    create(:contract, *traits,
           organization: organization,
           player: player,
           created_by: user,
           **overrides)
  end

  # ── Validations ─────────────────────────────────────────────────────────────

  describe 'validations' do
    describe 'contract_type' do
      it 'is valid for every allowed type' do
        Contract::TYPES.each do |type|
          contract = build_contract(contract_type: type)
          expect(contract).to be_valid, "expected #{type} to be valid"
        end
      end

      it 'is invalid for an unrecognised type' do
        contract = build_contract(contract_type: 'sponsorship')
        expect(contract).not_to be_valid
        expect(contract.errors[:contract_type]).to be_present
      end
    end

    describe 'end_date after start_date' do
      it 'is invalid when end_date equals start_date' do
        date = Date.current
        contract = build_contract(start_date: date, end_date: date)
        expect(contract).not_to be_valid
        expect(contract.errors[:end_date]).to include('must be after start date')
      end

      it 'is invalid when end_date is before start_date' do
        contract = build_contract(start_date: Date.current, end_date: Date.current - 1.day)
        expect(contract).not_to be_valid
        expect(contract.errors[:end_date]).to include('must be after start date')
      end

      it 'is valid when end_date is after start_date' do
        contract = build_contract(start_date: Date.current, end_date: Date.current + 1.day)
        expect(contract).to be_valid
      end
    end

    describe 'base_salary presence' do
      it 'is invalid without base_salary' do
        contract = build_contract(base_salary: nil)
        expect(contract).not_to be_valid
        expect(contract.errors[:base_salary]).to be_present
      end
    end

    describe 'status inclusion' do
      it 'is invalid for an unknown status' do
        contract = build_contract(status: 'suspended')
        expect(contract).not_to be_valid
        expect(contract.errors[:status]).to be_present
      end
    end

    describe 'salary_period inclusion' do
      it 'is invalid for an unknown salary_period' do
        contract = build_contract(salary_period: 'annually')
        expect(contract).not_to be_valid
        expect(contract.errors[:salary_period]).to be_present
      end
    end
  end

  # ── Scopes ───────────────────────────────────────────────────────────────────

  describe '.active scope' do
    it 'returns only contracts with status active' do
      active_contract = create_contract(:active)
      # Use a different player for the draft — the model prevents creating any
      # new contract (even draft) while the same player already has an active one.
      draft_player   = create(:player, organization: organization)
      draft_contract = create(:contract,
                              organization: organization,
                              player: draft_player,
                              created_by: user,
                              status: 'draft')

      expect(Contract.active).to include(active_contract)
      expect(Contract.active).not_to include(draft_contract)
    end
  end

  describe '.expiring scope' do
    it 'returns active contracts whose end_date falls within the next N days' do
      expiring = create_contract(:active, end_date: Date.current + 20.days)
      future   = create(:contract, :active,
                        organization: organization,
                        player: create(:player, organization: organization),
                        created_by: user,
                        end_date: Date.current + 90.days)

      results = Contract.expiring(30)
      expect(results).to include(expiring)
      expect(results).not_to include(future)
    end

    it 'does not return expired-status contracts even if end_date is within window' do
      past_but_expired = create(:contract,
                                organization: organization,
                                player: player,
                                created_by: user,
                                status: 'expired',
                                end_date: Date.current + 10.days)

      expect(Contract.expiring(30)).not_to include(past_but_expired)
    end

    it 'defaults to 30 days when no argument is given' do
      within  = create_contract(:active, end_date: Date.current + 29.days)
      outside = create(:contract, :active,
                       organization: organization,
                       player: create(:player, organization: organization),
                       created_by: user,
                       end_date: Date.current + 31.days)

      expect(Contract.expiring).to include(within)
      expect(Contract.expiring).not_to include(outside)
    end
  end

  # ── Instance methods ─────────────────────────────────────────────────────────

  describe '#days_remaining' do
    it 'returns a positive integer for a future end_date' do
      contract = build_contract(end_date: Date.current + 10.days)
      expect(contract.days_remaining).to eq(10)
    end

    it 'returns 0 when end_date is today (already expired as of today)' do
      contract = build_contract(end_date: Date.current)
      expect(contract.days_remaining).to eq(0)
    end

    it 'returns 0 when end_date is in the past' do
      contract = build_contract(start_date: 2.years.ago, end_date: 1.year.ago)
      expect(contract.days_remaining).to eq(0)
    end

    it 'is never negative' do
      contract = build_contract(start_date: 3.years.ago, end_date: 2.years.ago)
      expect(contract.days_remaining).to be >= 0
    end
  end

  describe '#expiring_soon?' do
    it 'returns true when active and expires within threshold' do
      contract = build_contract(status: 'active', end_date: Date.current + 20.days)
      expect(contract.expiring_soon?(30)).to be(true)
    end

    it 'returns false when active but expires beyond threshold' do
      contract = build_contract(status: 'active', end_date: Date.current + 60.days)
      expect(contract.expiring_soon?(30)).to be(false)
    end

    it 'returns false when not active even if end_date is near' do
      contract = build_contract(status: 'draft', end_date: Date.current + 5.days)
      expect(contract.expiring_soon?(30)).to be(false)
    end

    it 'defaults threshold to 30 when no argument is provided' do
      near = build_contract(status: 'active', end_date: Date.current + 29.days)
      far  = build_contract(status: 'active', end_date: Date.current + 31.days)

      expect(near.expiring_soon?).to be(true)
      expect(far.expiring_soon?).to be(false)
    end
  end

  # ── Overlap validation ───────────────────────────────────────────────────────

  describe 'no_overlapping_active_contract' do
    context 'when the player already has an active contract in the same organization' do
      before do
        create_contract(:active)
      end

      it 'prevents creating a second active contract for the same player' do
        duplicate = build_contract(:active)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:base]).to include('Player already has an active contract')
      end
    end

    context 'when the existing contract is not active' do
      before do
        create_contract(status: 'draft')
      end

      it 'allows creating an active contract alongside a draft one' do
        new_contract = build_contract(:active)
        expect(new_contract).to be_valid
      end
    end

    context 'when the player belongs to a different organization' do
      let(:other_org)    { create(:organization) }
      let(:other_user)   { create(:user, organization: other_org) }
      let(:other_player) { create(:player, organization: other_org) }

      before do
        create(:contract, :active,
               organization: other_org,
               player: other_player,
               created_by: other_user)
      end

      it 'allows an active contract for the same player in a different org' do
        new_contract = build_contract(:active)
        expect(new_contract).to be_valid
      end
    end
  end

  # ── Soft delete ──────────────────────────────────────────────────────────────

  describe '#soft_delete!' do
    it 'sets deleted_at without altering status' do
      contract = create_contract(:active)
      original_status = contract.status

      contract.soft_delete!

      expect(contract.reload.deleted_at).to be_present
      expect(contract.status).to eq(original_status)
    end
  end
end
