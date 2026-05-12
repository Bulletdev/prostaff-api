# frozen_string_literal: true

class AddGameFingerprintToCompetitiveMatches < ActiveRecord::Migration[7.1]
  def up
    add_column :competitive_matches, :game_fingerprint, :string
  end

  def down
    remove_column :competitive_matches, :game_fingerprint
  end
end
