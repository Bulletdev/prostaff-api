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

  describe 'drawing_data field' do
    it 'is present in the serialized output' do
      expect(result).to have_key(:drawing_data)
    end

    it 'returns an empty hash when no drawing has been saved' do
      expect(result[:drawing_data]).to eq({})
    end

    context 'when drawing_data has content' do
      let(:drawing_payload) { { 'shapes' => [{ 'id' => '1', 'type' => 'rect' }] } }
      let(:timestamp) do
        create(:vod_timestamp,
               vod_review: vod_review,
               target_player: player,
               created_by: reviewer,
               timestamp_seconds: 125,
               drawing_data: drawing_payload)
      end

      it 'serializes the stored drawing data' do
        expect(result[:drawing_data]).to eq(drawing_payload)
      end
    end
  end

  describe 'source_video_index field' do
    it 'is present in the serialized output' do
      expect(result).to have_key(:source_video_index)
    end

    it 'defaults to 0' do
      expect(result[:source_video_index]).to eq(0)
    end

    context 'when source_video_index is set to a non-zero value' do
      let(:timestamp) do
        create(:vod_timestamp,
               vod_review: vod_review,
               target_player: player,
               created_by: reviewer,
               timestamp_seconds: 125,
               source_video_index: 2)
      end

      it 'serializes the stored index' do
        expect(result[:source_video_index]).to eq(2)
      end
    end
  end

  describe 'annotations field' do
    it 'is present in the serialized output' do
      expect(result).to have_key(:annotations)
    end

    it 'returns an empty array when no annotations have been saved' do
      expect(result[:annotations]).to eq([])
    end

    context 'when annotations have content' do
      let(:annotations_payload) { [{ 'text' => 'bad positioning', 'at' => 30 }] }
      let(:timestamp) do
        create(:vod_timestamp,
               vod_review: vod_review,
               target_player: player,
               created_by: reviewer,
               timestamp_seconds: 125,
               annotations: annotations_payload)
      end

      it 'serializes the stored annotations' do
        expect(result[:annotations]).to eq(annotations_payload)
      end
    end
  end
end
