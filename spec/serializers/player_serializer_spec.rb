# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlayerSerializer do
  let(:organization) { create(:organization) }
  let(:player) { create(:player, organization: organization) }

  subject(:result) { described_class.render_as_hash(player) }

  it 'exposes identifier' do
    expect(result[:id]).to eq(player.id)
  end

  it 'exposes core player fields' do
    expect(result).to include(
      :summoner_name, :real_name, :role, :status,
      :solo_queue_tier, :solo_queue_rank, :solo_queue_lp,
      :solo_queue_wins, :solo_queue_losses,
      :sync_status, :created_at, :updated_at
    )
  end

  describe 'role field' do
    it 'is one of the five valid LoL roles' do
      expect(result[:role]).to be_in(%w[top jungle mid adc support])
    end
  end

  describe 'win_rate field' do
    it 'is within 0 to 100 range' do
      win_rate = result[:win_rate].to_f
      expect(win_rate).to be >= 0.0
      expect(win_rate).to be <= 100.0
    end
  end

  describe 'current_rank field' do
    it 'is present as a string or nil' do
      expect(result[:current_rank]).to be_a(String).or be_nil
    end
  end

  describe 'contract_status field' do
    it 'is present' do
      expect(result).to have_key(:contract_status)
    end
  end

  describe 'main_champions field' do
    it 'is an array' do
      expect(result[:main_champions]).to be_an(Array)
    end
  end

  describe 'social_links field' do
    it 'is a hash' do
      expect(result[:social_links]).to be_a(Hash)
    end
  end

  describe 'needs_sync field' do
    it 'is a boolean' do
      expect(result[:needs_sync]).to be_in([true, false])
    end
  end

  describe 'avatar_url field' do
    context 'when player has no avatar or profile icon' do
      let(:player) { create(:player, organization: organization, profile_icon_id: nil) }

      it 'is nil or a string' do
        expect(result[:avatar_url]).to be_nil.or be_a(String)
      end
    end
  end

  describe 'organization association' do
    it 'includes organization id' do
      expect(result[:organization][:id]).to eq(organization.id)
    end

    it 'includes organization name' do
      expect(result[:organization][:name]).to eq(organization.name)
    end
  end

  it 'does not expose internal fields' do
    expect(result.keys).not_to include(:password_digest, :jti)
  end
end
