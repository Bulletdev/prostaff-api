# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedBuildSerializer do
  let(:organization) { create(:organization) }
  let(:build) do
    create(:saved_build,
           organization: organization,
           champion: 'Jinx',
           role: 'adc',
           win_rate: 55.5,
           games_played: 40)
  end

  subject(:result) { described_class.render_as_hash(build) }

  it 'exposes identifier' do
    expect(result[:id]).to eq(build.id)
  end

  it 'exposes core fields' do
    expect(result).to include(
      :champion, :role, :patch_version, :title,
      :is_public, :data_source, :games_played,
      :items, :created_at, :updated_at
    )
  end

  describe 'champion field' do
    it 'is CamelCase (Riot Data Dragon format)' do
      expect(result[:champion]).to eq('Jinx')
      expect(result[:champion]).to match(/\A[A-Z]/)
    end
  end

  describe 'role field' do
    it 'is one of the five valid LoL roles' do
      expect(result[:role]).to be_in(%w[top jungle mid adc support])
    end
  end

  describe 'win_rate field' do
    it 'is within 0 to 100' do
      expect(result[:win_rate]).to be >= 0.0
      expect(result[:win_rate]).to be <= 100.0
    end

    it 'is a float rounded to 2 decimal places' do
      expect(result[:win_rate]).to be_a(Float)
    end

    context 'when win_rate is 0' do
      let(:build) { create(:saved_build, organization: organization, win_rate: 0.0) }

      it 'returns 0.0 without raising' do
        expect(result[:win_rate]).to eq(0.0)
      end
    end
  end

  describe 'average_kda field' do
    it 'is a non-negative float' do
      expect(result[:average_kda]).to be_a(Float)
      expect(result[:average_kda]).to be >= 0.0
    end
  end

  describe 'average_cs_per_min field' do
    it 'is a non-negative float' do
      expect(result[:average_cs_per_min]).to be_a(Float)
      expect(result[:average_cs_per_min]).to be >= 0.0
    end
  end

  describe 'average_damage_share field' do
    it 'is a non-negative float' do
      expect(result[:average_damage_share]).to be_a(Float)
      expect(result[:average_damage_share]).to be >= 0.0
    end
  end

  describe 'win_rate_display field' do
    it 'is a string' do
      expect(result[:win_rate_display]).to be_a(String)
    end
  end

  describe 'created_by_id field' do
    it 'is present' do
      expect(result).to have_key(:created_by_id)
    end
  end
end
