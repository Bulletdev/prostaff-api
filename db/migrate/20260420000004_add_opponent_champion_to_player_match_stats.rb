# frozen_string_literal: true

# Adds opponent_champion to player_match_stats for laning matchup context.
# Populated during match sync by finding the participant on the opposing team
# with the same teamPosition (role) as the tracked player.
class AddOpponentChampionToPlayerMatchStats < ActiveRecord::Migration[7.1]
  def change
    add_column :player_match_stats, :opponent_champion, :string

    add_index :player_match_stats, :opponent_champion,
              name: 'idx_pms_opponent_champion'
  end
end
