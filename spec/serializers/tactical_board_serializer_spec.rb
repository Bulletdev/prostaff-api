# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TacticalBoardSerializer do
  let(:organization) { create(:organization) }
  let(:creator) { create(:user, :admin, organization: organization) }
  let(:tactical_board) do
    create(:tactical_board,
           organization: organization,
           created_by: creator,
           updated_by: creator)
  end

  subject(:result) { described_class.render_as_hash(tactical_board) }

  it 'exposes identifier' do
    expect(result[:id]).to eq(tactical_board.id)
  end

  it 'exposes core fields' do
    expect(result).to include(
      :title, :game_time, :match_id, :scrim_id,
      :map_state, :annotations, :created_at, :updated_at
    )
  end

  describe 'total_players field' do
    context 'when map_state has no players' do
      let(:tactical_board) do
        create(:tactical_board, organization: organization,
                                created_by: creator, updated_by: creator,
                                map_state: { 'players' => [] })
      end

      it 'is 0' do
        expect(result[:total_players]).to eq(0)
      end
    end

    context 'when map_state has players' do
      let(:tactical_board) do
        # map_state players must include numeric x and y coordinates (model validation)
        create(:tactical_board,
               organization: organization,
               created_by: creator,
               updated_by: creator,
               map_state: {
                 'players' => [
                   { 'role' => 'mid', 'champion' => 'Azir', 'x' => 50.0, 'y' => 50.0 },
                   { 'role' => 'adc', 'champion' => 'Jinx', 'x' => 70.0, 'y' => 80.0 }
                 ]
               })
      end

      it 'is the count of players' do
        expect(result[:total_players]).to eq(2)
      end
    end
  end

  describe 'total_annotations field' do
    context 'when annotations is empty' do
      let(:tactical_board) do
        create(:tactical_board, organization: organization,
                                created_by: creator, updated_by: creator,
                                annotations: [])
      end

      it 'is 0' do
        expect(result[:total_annotations]).to eq(0)
      end
    end

    context 'when annotations has entries' do
      let(:tactical_board) do
        create(:tactical_board,
               organization: organization,
               created_by: creator,
               updated_by: creator,
               annotations: [{ 'type' => 'arrow' }, { 'type' => 'circle' }])
      end

      it 'is the count of annotations' do
        expect(result[:total_annotations]).to eq(2)
      end
    end
  end

  describe 'auto_title field' do
    it 'is present' do
      expect(result).to have_key(:auto_title)
    end
  end

  describe 'organization association' do
    it 'includes organization id' do
      expect(result[:organization][:id]).to eq(organization.id)
    end
  end

  describe 'created_by association' do
    it 'includes user id' do
      expect(result[:created_by][:id]).to eq(creator.id)
    end

    it 'does not expose password_digest' do
      expect(result[:created_by].keys).not_to include(:password_digest)
    end
  end
end
