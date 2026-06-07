# frozen_string_literal: true

require 'rails_helper'

# Security test: verifies that PlayerSerializer enforces view-level separation
# between financial data (contract terms) and non-financial roles.
#
# Roles coach / analyst / viewer receive the default view — they must NEVER see
# contract start_date, end_date, or the embedded active_contract object.
# Roles owner / admin / manager receive view :with_contract — they see the
# embedded contract but still not raw date fields at the top level.
RSpec.describe PlayerSerializer do
  let(:org)    { create(:organization) }
  let(:admin)  { create(:user, :admin, organization: org) }
  let(:player) { create(:player, organization: org) }

  # ── :default view ──────────────────────────────────────────────────────────

  context 'view :default (coach, analyst, viewer)' do
    subject(:payload) do
      PlayerSerializer.render_as_hash(player, root: :player)
    end

    it 'does not include contract_start_date at top level' do
      expect(payload[:player]).not_to have_key(:contract_start_date)
    end

    it 'does not include contract_end_date at top level' do
      expect(payload[:player]).not_to have_key(:contract_end_date)
    end

    it 'does not include active_contract object' do
      expect(payload[:player]).not_to have_key(:active_contract)
    end

    it 'includes contract_status (public-safe field)' do
      expect(payload[:player]).to have_key(:contract_status)
    end

    it 'contract_status is one of the allowed strings' do
      allowed = ['No contract', 'Active', 'Expiring soon']
      expect(allowed).to include(payload[:player][:contract_status])
    end

    it 'includes role and role is a valid LoL role' do
      valid_roles = %w[top jungle mid adc support]
      expect(valid_roles).to include(payload[:player][:role])
    end

    it 'includes summoner_name' do
      expect(payload[:player]).to have_key(:summoner_name)
    end

    it 'includes win_rate and it is within [0, 100]' do
      win_rate = payload[:player][:win_rate]
      expect(win_rate).to be_a(Numeric)
      expect(win_rate).to be >= 0
      expect(win_rate).to be <= 100
    end
  end

  # ── :with_contract view ────────────────────────────────────────────────────

  context 'view :with_contract (owner, admin, manager)' do
    subject(:payload) do
      PlayerSerializer.render_as_hash(player, root: :player, view: :with_contract)
    end

    it 'includes active_contract key' do
      expect(payload[:player]).to have_key(:active_contract)
    end

    it 'does not include contract_start_date as a top-level field' do
      expect(payload[:player]).not_to have_key(:contract_start_date)
    end

    it 'does not include contract_end_date as a top-level field' do
      expect(payload[:player]).not_to have_key(:contract_end_date)
    end

    context 'when the player has an active contract' do
      let!(:contract) do
        create(:contract, :active,
               organization: org,
               player: player,
               created_by: admin,
               base_salary: 8000.00,
               end_date: Date.current + 6.months)
      end

      it 'active_contract is not nil' do
        expect(payload[:player][:active_contract]).not_to be_nil
      end

      it 'active_contract includes status' do
        expect(payload[:player][:active_contract]).to have_key(:status)
        expect(payload[:player][:active_contract][:status]).to eq('active')
      end

      it 'active_contract includes end_date' do
        expect(payload[:player][:active_contract]).to have_key(:end_date)
      end

      it 'active_contract includes base_salary' do
        expect(payload[:player][:active_contract]).to have_key(:base_salary)
      end

      it 'active_contract includes days_remaining and it is non-negative' do
        days = payload[:player][:active_contract][:days_remaining]
        expect(days).to be_a(Integer)
        expect(days).to be >= 0
      end
    end

    context 'when the player has no active contract' do
      it 'active_contract is nil' do
        expect(payload[:player][:active_contract]).to be_nil
      end
    end
  end
end
