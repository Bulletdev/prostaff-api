# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VodTimestampSerializer do
  let(:organization) { create(:organization) }
  let(:reviewer) { create(:user, :coach, organization: organization) }
  let(:player) { create(:player, organization: organization) }
  let(:vod_review) do
    create(:vod_review, organization: organization, reviewer: reviewer,
                        match: create(:match, organization: organization))
  end
  let(:timestamp) do
    create(:vod_timestamp,
           vod_review: vod_review,
           target_player: player,
           created_by: reviewer,
           timestamp_seconds: 125)
  end

  subject(:result) { described_class.render_as_hash(timestamp) }

  it 'exposes identifier' do
    expect(result[:id]).to eq(timestamp.id)
  end

  it 'exposes core fields' do
    expect(result).to include(
      :timestamp_seconds, :category, :importance,
      :title, :description, :created_at, :updated_at
    )
  end

  describe 'timestamp_seconds field' do
    it 'is non-negative' do
      expect(result[:timestamp_seconds]).to be >= 0
    end
  end

  describe 'formatted_timestamp field' do
    context 'when under one hour (125 seconds)' do
      it 'formats as MM:SS' do
        expect(result[:formatted_timestamp]).to eq('02:05')
      end
    end

    context 'when over one hour' do
      let(:timestamp) do
        create(:vod_timestamp,
               vod_review: vod_review,
               target_player: player,
               created_by: reviewer,
               timestamp_seconds: 3725)
      end

      it 'formats as HH:MM:SS' do
        expect(result[:formatted_timestamp]).to eq('01:02:05')
      end
    end

    context 'when timestamp is 0 seconds' do
      let(:timestamp) do
        create(:vod_timestamp,
               vod_review: vod_review,
               target_player: player,
               created_by: reviewer,
               timestamp_seconds: 0)
      end

      it 'formats as 00:00' do
        expect(result[:formatted_timestamp]).to eq('00:00')
      end
    end
  end

  describe 'vod_review association' do
    it 'includes vod_review id' do
      expect(result[:vod_review][:id]).to eq(vod_review.id)
    end
  end

  describe 'target_player association' do
    it 'includes player id' do
      expect(result[:target_player][:id]).to eq(player.id)
    end
  end

  describe 'created_by association' do
    it 'includes user id' do
      expect(result[:created_by][:id]).to eq(reviewer.id)
    end

    it 'does not expose password_digest' do
      expect(result[:created_by].keys).not_to include(:password_digest)
    end
  end
end
