class CreateCompetitiveMatches < ActiveRecord::Migration[7.2]
  def change
    create_table :competitive_matches, id: :uuid do |t|
      t.uuid :organization_id, null: false
      t.string :tournament_name, null: false
      t.string :tournament_stage # Groups, Playoffs, Finals, etc
      t.string :tournament_region # CBLOL, LCS, Worlds, MSI, etc

      # Match data
      t.string :external_match_id # PandaScore/Leaguepedia ID
      t.datetime :match_date
      t.string :match_format # BO1, BO3, BO5
      t.integer :game_number # Qual game do BO (1, 2, 3)

      # Teams
      t.string :our_team_name
      t.string :opponent_team_name
      t.uuid :opponent_team_id

      # Results
      t.boolean :victory
      t.string :series_score # "2-1", "3-0", etc

      # Draft data (CRUCIAL para análise)
      t.jsonb :our_bans, default: []      # [{champion: "Aatrox", order: 1}, ...]
      t.jsonb :opponent_bans, default: []
      t.jsonb :our_picks, default: []     # [{champion: "Lee Sin", role: "jungle", order: 1}, ...]
      t.jsonb :opponent_picks, default: []
      t.string :side # blue/red

      # In-game stats
      t.uuid :match_id # Link para Match model existente (se tivermos replay)
      t.jsonb :game_stats, default: {}

      # Meta context
      t.string :patch_version
      t.text :meta_champions, array: true, default: []

      # External links
      t.string :vod_url
      t.string :external_stats_url

      t.timestamps
    end

    add_index :competitive_matches, :organization_id
    add_index :competitive_matches, [:organization_id, :tournament_name], name: 'idx_comp_matches_org_tournament'
    add_index :competitive_matches, [:tournament_region, :match_date], name: 'idx_comp_matches_region_date'
    add_index :competitive_matches, :external_match_id, unique: true
    add_index :competitive_matches, :patch_version
    add_index :competitive_matches, :match_date
    add_index :competitive_matches, :opponent_team_id

    add_foreign_key :competitive_matches, :organizations
    add_foreign_key :competitive_matches, :opponent_teams
    add_foreign_key :competitive_matches, :matches
  end
end
