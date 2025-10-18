class CreateOpponentTeams < ActiveRecord::Migration[7.2]
  def change
    create_table :opponent_teams, id: :uuid do |t|
      t.string :name, null: false
      t.string :tag
      t.string :region
      t.string :tier # tier_1, tier_2, tier_3
      t.string :league # CBLOL, LCS, LCK, etc

      # Team info
      t.string :logo_url
      t.text :known_players, array: true, default: []
      t.jsonb :recent_performance, default: {}

      # Scrim history
      t.integer :total_scrims, default: 0
      t.integer :scrims_won, default: 0
      t.integer :scrims_lost, default: 0

      # Strategic notes
      t.text :playstyle_notes
      t.text :strengths, array: true, default: []
      t.text :weaknesses, array: true, default: []
      t.jsonb :preferred_champions, default: {} # By role

      # Contact
      t.string :contact_email
      t.string :discord_server

      t.timestamps
    end

    add_index :opponent_teams, :name
    add_index :opponent_teams, :tier
    add_index :opponent_teams, :region
    add_index :opponent_teams, :league
  end
end
