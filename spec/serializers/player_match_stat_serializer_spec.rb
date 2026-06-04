# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlayerMatchStatSerializer do
  let(:organization) { create(:organization) }
  let(:player) { create(:player, organization: organization) }
  let(:match) { create(:match, organization: organization) }
  let(:stat) do
    create(:player_match_stat,
           player: player,
           match: match,
           kills: 5,
           deaths: 2,
           assists: 8)
  end

  subject(:result) { described_class.render_as_hash(stat) }

  it 'exposes identifier' do
    expect(result[:id]).to eq(stat.id)
  end

  it 'exposes core stat fields' do
    expect(result).to include(
      :role, :champion, :kills, :deaths, :assists,
      :gold_earned, :vision_score, :created_at, :updated_at
    )
  end

  describe 'role field' do
    it 'is one of the five valid LoL roles' do
      expect(result[:role]).to be_in(%w[top jungle mid adc support])
    end
  end

  describe 'kda field' do
    it 'is never negative' do
      expect(result[:kda]).to be >= 0.0
    end

    context 'when deaths is 0' do
      let(:stat) do
        create(:player_match_stat,
               player: player, match: match,
               kills: 7, deaths: 0, assists: 3)
      end

      it 'avoids division by zero by using 1 as denominator' do
        # serializer uses deaths.zero? ? 1 : deaths
        expect(result[:kda]).to eq(10.0)
      end
    end

    context 'when kills and assists are both 0 and deaths is positive' do
      let(:stat) do
        create(:player_match_stat,
               player: player, match: match,
               kills: 0, deaths: 5, assists: 0)
      end

      it 'is 0.0' do
        expect(result[:kda]).to eq(0.0)
      end
    end

    context 'with standard stats' do
      it 'calculates correctly: (kills + assists) / deaths' do
        # (5 + 8) / 2 = 6.5
        expect(result[:kda]).to eq(6.5)
      end
    end
  end

  describe 'cs_total field' do
    it 'is an integer >= 0' do
      expect(result[:cs_total]).to be_a(Integer)
      expect(result[:cs_total]).to be >= 0
    end
  end

  describe 'champion_icon_url field' do
    it 'is present' do
      expect(result).to have_key(:champion_icon_url)
    end
  end

  describe 'items field' do
    it 'is an array' do
      expect(result[:items]).to be_an(Array)
    end
  end

  describe 'runes field' do
    it 'is an array' do
      expect(result[:runes]).to be_an(Array)
    end
  end

  describe 'summoner_spells field' do
    it 'is an array' do
      expect(result[:summoner_spells]).to be_an(Array)
    end
  end

  describe 'player association' do
    it 'includes the associated player id' do
      expect(result[:player][:id]).to eq(player.id)
    end
  end

  describe 'match association' do
    it 'includes the associated match id' do
      expect(result[:match][:id]).to eq(match.id)
    end
  end
end
