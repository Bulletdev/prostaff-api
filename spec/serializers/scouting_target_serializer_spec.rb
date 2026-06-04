# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScoutingTargetSerializer do
  let(:target) { create(:scouting_target) }

  subject(:result) { described_class.render_as_hash(target) }

  it 'exposes identifier' do
    expect(result[:id]).to eq(target.id)
  end

  it 'exposes core fields' do
    expect(result).to include(
      :summoner_name, :role, :region, :status,
      :current_tier, :current_rank, :current_lp,
      :champion_pool, :created_at, :updated_at
    )
  end

  describe 'role field' do
    it 'is one of the five valid LoL roles' do
      expect(result[:role]).to be_in(%w[top jungle mid adc support])
    end
  end

  describe 'status_text field' do
    it 'is a string' do
      expect(result[:status_text]).to be_a(String)
    end
  end

  describe 'current_rank_display field' do
    it 'is present' do
      expect(result).to have_key(:current_rank_display)
    end
  end

  describe 'champion_pool field' do
    it 'is an array' do
      expect(result[:champion_pool]).to be_an(Array)
    end
  end

  describe 'in_watchlist field' do
    context 'without watchlist context' do
      it 'is false' do
        expect(result[:in_watchlist]).to be(false)
      end
    end

    context 'with a watchlist object in options' do
      let(:organization) { create(:organization) }
      let(:user) { create(:user, organization: organization) }
      let(:watchlist) do
        create(:scouting_watchlist,
               organization: organization,
               scouting_target: target,
               added_by: user,
               priority: 'high',
               status: 'watching')
      end

      subject(:result) { described_class.render_as_hash(target, watchlist: watchlist) }

      it 'is true' do
        expect(result[:in_watchlist]).to be(true)
      end

      it 'exposes watchlist priority' do
        expect(result[:priority]).to eq('high')
      end

      it 'exposes watchlist status' do
        expect(result[:watchlist_status]).to eq('watching')
      end
    end
  end

  describe 'avatar_url field' do
    it 'is nil or a string' do
      expect(result[:avatar_url]).to be_nil.or be_a(String)
    end
  end
end
