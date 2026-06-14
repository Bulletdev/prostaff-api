# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_06_13_200200) do
  create_schema "auth"

  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "ai_champion_matrices", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "champion_a", null: false
    t.string "champion_b", null: false
    t.integer "wins_a", default: 0, null: false
    t.integer "total_games", default: 0, null: false
    t.string "patch"
    t.string "league"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["champion_a", "champion_b", "patch", "league"], name: "index_ai_champion_matrices_unique", unique: true, where: "((patch IS NOT NULL) AND (league IS NOT NULL))"
    t.index ["champion_a", "champion_b"], name: "index_ai_champion_matrices_null_pair", unique: true, where: "((patch IS NULL) AND (league IS NULL))"
    t.index ["champion_a", "champion_b"], name: "index_ai_champion_matrices_on_pair"
  end

  create_table "ai_champion_vectors", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "champion_name", null: false
    t.jsonb "vector_data", default: [], null: false
    t.integer "games_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["champion_name"], name: "index_ai_champion_vectors_on_champion_name", unique: true
  end

  create_table "audit_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.uuid "user_id"
    t.string "action", null: false
    t.string "entity_type", null: false
    t.uuid "entity_id"
    t.jsonb "old_values"
    t.jsonb "new_values"
    t.inet "ip_address"
    t.text "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["entity_id"], name: "index_audit_logs_on_entity_id"
    t.index ["entity_type", "entity_id"], name: "index_audit_logs_on_entity_type_and_entity_id"
    t.index ["entity_type"], name: "index_audit_logs_on_entity_type"
    t.index ["organization_id", "created_at"], name: "index_audit_logs_on_org_and_created"
    t.index ["organization_id"], name: "index_audit_logs_on_organization_id"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "availability_windows", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.integer "day_of_week", null: false
    t.integer "start_hour", null: false
    t.integer "end_hour", null: false
    t.string "timezone", default: "UTC", null: false
    t.string "game", default: "league_of_legends", null: false
    t.string "region"
    t.string "tier_preference", default: "any"
    t.boolean "active", default: true, null: false
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "focus_area"
    t.string "draft_type"
    t.index ["day_of_week"], name: "index_availability_windows_on_day_of_week"
    t.index ["game", "region", "active"], name: "index_availability_windows_on_game_and_region_and_active"
    t.index ["organization_id", "active"], name: "index_availability_windows_on_organization_id_and_active"
    t.index ["organization_id"], name: "index_availability_windows_on_organization_id"
  end

  create_table "budget_allocations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.uuid "created_by_id", null: false
    t.string "name", null: false
    t.string "period_type", null: false
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.decimal "total_budget", precision: 14, scale: 2, null: false
    t.string "currency", default: "BRL"
    t.string "lineup", default: "main"
    t.text "notes"
    t.string "status", default: "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "start_date", "end_date"], name: "idx_budget_allocs_period"
    t.index ["organization_id", "status"], name: "index_budget_allocations_on_organization_id_and_status"
  end

  create_table "champion_patch_stats", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "champion_name", null: false
    t.string "league", null: false
    t.string "patch", null: false
    t.string "role"
    t.integer "blue_bans", default: 0, null: false
    t.integer "red_bans", default: 0, null: false
    t.integer "blue_picks", default: 0, null: false
    t.integer "red_picks", default: 0, null: false
    t.integer "wins", default: 0, null: false
    t.integer "games", default: 0, null: false
    t.integer "ban_count_per_team", default: 5, null: false
    t.float "presence_rate"
    t.float "win_rate"
    t.float "avg_pick_order"
    t.datetime "computed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["champion_name", "league", "patch", "role"], name: "uq_champion_patch_stats", unique: true
    t.index ["league", "patch"], name: "index_champion_patch_stats_on_league_and_patch"
  end

  create_table "champion_pools", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "player_id", null: false
    t.string "champion", null: false
    t.integer "games_played", default: 0
    t.integer "games_won", default: 0
    t.integer "mastery_level", default: 1
    t.decimal "average_kda", precision: 5, scale: 2
    t.decimal "average_cs_per_min", precision: 5, scale: 2
    t.decimal "average_damage_share", precision: 5, scale: 2
    t.boolean "is_comfort_pick", default: false
    t.boolean "is_pocket_pick", default: false
    t.boolean "is_learning", default: false
    t.integer "priority", default: 5
    t.datetime "last_played", precision: nil
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["champion"], name: "index_champion_pools_on_champion"
    t.index ["player_id", "champion"], name: "index_champion_pools_on_player_id_and_champion", unique: true
    t.index ["player_id"], name: "index_champion_pools_on_player_id"
    t.index ["priority"], name: "index_champion_pools_on_priority"
  end

  create_table "competitive_matches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.string "tournament_name", null: false
    t.string "tournament_stage"
    t.string "tournament_region"
    t.string "external_match_id"
    t.datetime "match_date"
    t.string "match_format"
    t.integer "game_number"
    t.string "our_team_name"
    t.string "opponent_team_name"
    t.uuid "opponent_team_id"
    t.boolean "victory"
    t.string "series_score"
    t.jsonb "our_bans", default: []
    t.jsonb "opponent_bans", default: []
    t.jsonb "our_picks", default: []
    t.jsonb "opponent_picks", default: []
    t.string "side"
    t.uuid "match_id"
    t.jsonb "game_stats", default: {}
    t.string "patch_version"
    t.text "meta_champions", default: [], array: true
    t.string "vod_url"
    t.string "external_stats_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "game_fingerprint"
    t.index ["match_date"], name: "index_competitive_matches_on_match_date"
    t.index ["opponent_team_id"], name: "index_competitive_matches_on_opponent_team_id"
    t.index ["organization_id", "external_match_id"], name: "index_competitive_matches_on_org_and_external_match_id", unique: true
    t.index ["organization_id", "tournament_name"], name: "idx_comp_matches_org_tournament"
    t.index ["organization_id"], name: "index_competitive_matches_on_organization_id"
    t.index ["patch_version"], name: "index_competitive_matches_on_patch_version"
    t.index ["tournament_region", "match_date"], name: "idx_comp_matches_region_date"
  end

  create_table "contract_bonuses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "contract_id", null: false
    t.uuid "organization_id", null: false
    t.string "bonus_type", null: false
    t.string "trigger", null: false
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.string "currency", default: "BRL"
    t.string "status", default: "pending"
    t.date "achieved_at"
    t.date "paid_at"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contract_id"], name: "index_contract_bonuses_on_contract_id"
    t.index ["organization_id", "status"], name: "index_contract_bonuses_on_organization_id_and_status"
  end

  create_table "contracts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.uuid "player_id", null: false
    t.uuid "created_by_id", null: false
    t.uuid "updated_by_id"
    t.string "contract_type", null: false
    t.string "status", default: "draft", null: false
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.date "signed_at"
    t.date "terminated_at"
    t.decimal "base_salary", precision: 12, scale: 2, default: "0.0", null: false
    t.string "salary_currency", default: "BRL", null: false
    t.string "salary_period", default: "monthly", null: false
    t.boolean "auto_renewal", default: false
    t.integer "renewal_notice_days", default: 30
    t.uuid "renewed_from_id"
    t.text "notes"
    t.jsonb "metadata", default: {}
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "end_date", "status"], name: "idx_contracts_expiry_lookup"
    t.index ["organization_id", "end_date"], name: "index_contracts_on_organization_id_and_end_date"
    t.index ["organization_id", "status"], name: "index_contracts_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_contracts_on_organization_id"
    t.index ["player_id", "status"], name: "index_contracts_on_player_id_and_status"
    t.index ["player_id"], name: "index_contracts_on_player_id"
    t.index ["renewed_from_id"], name: "index_contracts_on_renewed_from_id"
  end

  create_table "draft_plans", force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.string "opponent_team", null: false
    t.string "side", null: false
    t.string "patch_version"
    t.jsonb "our_bans", default: []
    t.jsonb "opponent_bans", default: []
    t.jsonb "priority_picks", default: {}
    t.jsonb "if_then_scenarios", default: []
    t.text "notes"
    t.boolean "is_active", default: true
    t.uuid "created_by_id", null: false
    t.uuid "updated_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_draft_plans_on_created_by_id"
    t.index ["organization_id", "is_active"], name: "index_draft_plans_on_organization_id_and_is_active"
    t.index ["organization_id", "opponent_team"], name: "index_draft_plans_on_organization_id_and_opponent_team"
    t.index ["organization_id"], name: "index_draft_plans_on_organization_id"
    t.index ["patch_version"], name: "index_draft_plans_on_patch_version"
    t.index ["updated_by_id"], name: "index_draft_plans_on_updated_by_id"
  end

  create_table "draft_simulations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.string "series_id", null: false
    t.integer "game_number", default: 1, null: false
    t.string "patch"
    t.string "league"
    t.string "our_side"
    t.string "team1_name"
    t.string "team2_name"
    t.boolean "fearless", default: false
    t.jsonb "blue_bans", default: []
    t.jsonb "red_bans", default: []
    t.jsonb "blue_picks", default: []
    t.jsonb "red_picks", default: []
    t.boolean "done", default: false
    t.jsonb "fearless_used", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "series_id", "game_number"], name: "index_draft_simulations_on_org_series_game", unique: true
    t.index ["organization_id"], name: "index_draft_simulations_on_organization_id"
    t.index ["series_id"], name: "index_draft_simulations_on_series_id"
  end

  create_table "expenses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.uuid "budget_allocation_id"
    t.uuid "created_by_id", null: false
    t.uuid "approved_by_id"
    t.uuid "player_id"
    t.string "category", null: false
    t.string "description", null: false
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.string "currency", default: "BRL"
    t.date "expense_date", null: false
    t.string "status", default: "pending"
    t.string "payment_method"
    t.date "paid_at"
    t.string "receipt_url"
    t.text "notes"
    t.boolean "recurring", default: false
    t.string "recurrence_rule"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["budget_allocation_id"], name: "index_expenses_on_budget_allocation_id"
    t.index ["organization_id", "category"], name: "index_expenses_on_organization_id_and_category"
    t.index ["organization_id", "expense_date"], name: "index_expenses_on_organization_id_and_expense_date"
    t.index ["organization_id", "status"], name: "index_expenses_on_organization_id_and_status"
    t.index ["player_id", "category"], name: "index_expenses_on_player_id_and_category"
  end

  create_table "feedback_votes", force: :cascade do |t|
    t.bigint "feedback_id", null: false
    t.uuid "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feedback_id", "user_id"], name: "index_feedback_votes_on_feedback_id_and_user_id", unique: true
    t.index ["feedback_id"], name: "index_feedback_votes_on_feedback_id"
    t.index ["user_id"], name: "index_feedback_votes_on_user_id"
  end

  create_table "feedbacks", force: :cascade do |t|
    t.uuid "user_id"
    t.uuid "organization_id"
    t.string "category", null: false
    t.string "title", null: false
    t.text "description", null: false
    t.integer "rating"
    t.string "status", default: "open", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "votes_count", default: 0, null: false
    t.string "source", default: "prostaff", null: false
    t.index ["category"], name: "index_feedbacks_on_category"
    t.index ["organization_id"], name: "index_feedbacks_on_organization_id"
    t.index ["source"], name: "index_feedbacks_on_source"
    t.index ["status"], name: "index_feedbacks_on_status"
    t.index ["user_id"], name: "index_feedbacks_on_user_id"
  end

  create_table "inhouse_participations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "inhouse_id", null: false
    t.uuid "player_id", null: false
    t.string "team", default: "none", null: false
    t.string "tier_snapshot"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "wins", default: 0, null: false
    t.integer "losses", default: 0, null: false
    t.boolean "is_captain", default: false, null: false
    t.string "role"
    t.float "mu_snapshot"
    t.float "sigma_snapshot"
    t.integer "mmr_delta"
    t.index ["inhouse_id", "player_id"], name: "index_inhouse_participations_on_inhouse_id_and_player_id", unique: true
    t.index ["inhouse_id"], name: "index_inhouse_participations_on_inhouse_id"
    t.index ["player_id"], name: "index_inhouse_participations_on_player_id"
  end

  create_table "inhouse_queue_entries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "inhouse_queue_id", null: false
    t.uuid "player_id", null: false
    t.string "role", null: false
    t.string "tier_snapshot"
    t.boolean "checked_in", default: false, null: false
    t.datetime "checked_in_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["inhouse_queue_id", "player_id"], name: "index_inhouse_queue_entries_on_inhouse_queue_id_and_player_id", unique: true
    t.index ["inhouse_queue_id", "role"], name: "index_inhouse_queue_entries_on_inhouse_queue_id_and_role"
    t.index ["inhouse_queue_id"], name: "index_inhouse_queue_entries_on_inhouse_queue_id"
    t.index ["player_id"], name: "index_inhouse_queue_entries_on_player_id"
  end

  create_table "inhouse_queues", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.string "status", default: "open", null: false
    t.datetime "check_in_deadline"
    t.uuid "created_by_user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_inhouse_queues_on_organization_id"
  end

  create_table "inhouses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.string "status", default: "waiting", null: false
    t.uuid "created_by_user_id", null: false
    t.integer "games_played", default: 0, null: false
    t.integer "blue_wins", default: 0, null: false
    t.integer "red_wins", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "blue_captain_id"
    t.uuid "red_captain_id"
    t.integer "draft_pick_number"
    t.string "formation_mode"
    t.index ["organization_id"], name: "index_inhouses_on_organization_id"
  end

  create_table "match_reports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tournament_match_id", null: false
    t.uuid "tournament_team_id", null: false
    t.uuid "reported_by_user_id"
    t.integer "team_a_score", default: 0, null: false
    t.integer "team_b_score", default: 0, null: false
    t.string "evidence_url"
    t.string "status", default: "pending", null: false
    t.datetime "submitted_at"
    t.datetime "confirmed_at"
    t.datetime "deadline_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reported_by_user_id"], name: "index_match_reports_on_reported_by_user_id"
    t.index ["status"], name: "index_match_reports_on_status"
    t.index ["tournament_match_id", "tournament_team_id"], name: "idx_match_reports_unique_per_team", unique: true
    t.index ["tournament_match_id"], name: "index_match_reports_on_tournament_match_id"
    t.index ["tournament_team_id"], name: "index_match_reports_on_tournament_team_id"
  end

  create_table "matches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.string "match_type", null: false
    t.string "riot_match_id"
    t.string "game_version"
    t.datetime "game_start", precision: nil
    t.datetime "game_end", precision: nil
    t.integer "game_duration"
    t.string "our_side"
    t.string "opponent_name"
    t.string "opponent_tag"
    t.boolean "victory"
    t.integer "our_score"
    t.integer "opponent_score"
    t.integer "our_towers"
    t.integer "opponent_towers"
    t.integer "our_dragons"
    t.integer "opponent_dragons"
    t.integer "our_barons"
    t.integer "opponent_barons"
    t.integer "our_inhibitors"
    t.integer "opponent_inhibitors"
    t.text "our_bans", default: [], array: true
    t.text "opponent_bans", default: [], array: true
    t.string "vod_url"
    t.string "replay_file_url"
    t.text "tags", default: [], array: true
    t.text "notes"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_start"], name: "index_matches_on_game_start"
    t.index ["match_type"], name: "index_matches_on_match_type"
    t.index ["organization_id", "created_at"], name: "idx_matches_org_created"
    t.index ["organization_id", "game_start", "victory"], name: "idx_matches_org_game_start_victory", comment: "Otimiza queries de winrate por período"
    t.index ["organization_id", "id"], name: "idx_matches_org_id"
    t.index ["organization_id", "match_type"], name: "idx_matches_org_match_type"
    t.index ["organization_id"], name: "index_matches_on_organization_id"
    t.index ["riot_match_id"], name: "index_matches_on_riot_match_id", unique: true
    t.index ["victory"], name: "index_matches_on_victory"
  end

  create_table "messages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "recipient_id"
    t.uuid "organization_id", null: false
    t.text "content", null: false
    t.boolean "deleted", default: false, null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "recipient_type", default: "User", null: false
    t.string "sender_type", default: "User", null: false
    t.index ["organization_id", "recipient_id", "user_id", "created_at"], name: "idx_messages_dm_reverse"
    t.index ["organization_id", "user_id", "recipient_id", "created_at"], name: "idx_messages_active_dm", where: "(deleted = false)"
    t.index ["organization_id", "user_id", "recipient_id", "created_at"], name: "idx_messages_dm_created_at"
    t.index ["organization_id"], name: "index_messages_on_organization_id"
    t.index ["recipient_id"], name: "index_messages_on_recipient_id"
    t.index ["user_id"], name: "index_messages_on_user_id"
  end

  create_table "ml_prediction_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "match_id"
    t.jsonb "blue_picks", default: [], null: false
    t.jsonb "red_picks", default: [], null: false
    t.string "patch"
    t.string "league"
    t.decimal "predicted_win_prob", precision: 5, scale: 4, null: false
    t.string "model_version"
    t.string "source"
    t.boolean "blue_won"
    t.timestamptz "predicted_at", default: -> { "now()" }, null: false
    t.timestamptz "outcome_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["match_id"], name: "index_ml_prediction_logs_on_match_id"
    t.index ["predicted_at"], name: "index_ml_prediction_logs_on_predicted_at", order: :desc
  end

  create_table "notifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "title", limit: 200, null: false
    t.text "message", null: false
    t.string "type", null: false
    t.text "link_url"
    t.string "link_type", limit: 20
    t.uuid "link_id"
    t.boolean "is_read", default: false
    t.datetime "read_at", precision: nil
    t.text "channels", default: ["in_app"], array: true
    t.boolean "email_sent", default: false
    t.boolean "discord_sent", default: false
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_notifications_on_created_at", order: :desc
    t.index ["is_read"], name: "index_notifications_on_is_read"
    t.index ["user_id"], name: "index_notifications_on_user_id"
    t.check_constraint "type::text = ANY (ARRAY['info'::character varying, 'success'::character varying, 'warning'::character varying, 'error'::character varying, 'match'::character varying, 'schedule'::character varying, 'system'::character varying]::text[])", name: "notifications_type_check"
  end

  create_table "opponent_teams", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "tag"
    t.string "region"
    t.string "tier"
    t.string "league"
    t.string "logo_url"
    t.text "known_players", default: [], array: true
    t.jsonb "recent_performance", default: {}
    t.integer "total_scrims", default: 0
    t.integer "scrims_won", default: 0
    t.integer "scrims_lost", default: 0
    t.text "playstyle_notes"
    t.text "strengths", default: [], array: true
    t.text "weaknesses", default: [], array: true
    t.jsonb "preferred_champions", default: {}
    t.string "contact_email"
    t.string "discord_server"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["league"], name: "index_opponent_teams_on_league"
    t.index ["name"], name: "index_opponent_teams_on_name"
    t.index ["region"], name: "index_opponent_teams_on_region"
    t.index ["tier"], name: "index_opponent_teams_on_tier"
  end

  create_table "organizations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "region", null: false
    t.string "tier"
    t.string "subscription_plan"
    t.string "subscription_status"
    t.string "logo_url"
    t.jsonb "settings", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "trial_expires_at"
    t.datetime "trial_started_at"
    t.boolean "is_public", default: false, null: false
    t.string "public_tagline", limit: 200
    t.string "discord_invite_url"
    t.string "team_tag", limit: 5
    t.string "enabled_lines", default: ["main"], null: false, array: true
    t.string "competitive_team_name", comment: "Competitive team name used to identify the org's matches in Leaguepedia (e.g. 'paiN Gaming')"
    t.index ["enabled_lines"], name: "index_organizations_on_enabled_lines", using: :gin
    t.index ["is_public"], name: "index_organizations_on_is_public", where: "(is_public = true)"
    t.index ["region"], name: "index_organizations_on_region"
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
    t.index ["subscription_plan"], name: "index_organizations_on_subscription_plan"
    t.index ["subscription_status"], name: "index_organizations_on_subscription_status"
    t.index ["trial_expires_at"], name: "index_organizations_on_trial_expires_at"
  end

  create_table "password_reset_tokens", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.string "token", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "expires_at", null: false
    t.datetime "used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "player_id"
    t.index ["expires_at"], name: "index_password_reset_tokens_on_expires_at"
    t.index ["player_id"], name: "index_password_reset_tokens_on_player_id"
    t.index ["token"], name: "index_password_reset_tokens_on_token", unique: true
    t.index ["user_id", "used_at"], name: "index_password_reset_tokens_on_user_id_and_used_at"
    t.index ["user_id"], name: "index_password_reset_tokens_on_user_id"
    t.check_constraint "user_id IS NOT NULL AND player_id IS NULL OR user_id IS NULL AND player_id IS NOT NULL", name: "chk_token_owner"
  end

  create_table "player_inhouse_ratings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "player_id", null: false
    t.uuid "organization_id", null: false
    t.string "role", null: false
    t.float "mu", default: 25.0, null: false
    t.float "sigma", default: 8.333333333333334, null: false
    t.integer "games_played", default: 0, null: false
    t.integer "wins", default: 0, null: false
    t.integer "losses", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "role"], name: "index_player_inhouse_ratings_on_organization_id_and_role"
    t.index ["organization_id"], name: "index_player_inhouse_ratings_on_organization_id"
    t.index ["player_id", "role"], name: "index_player_inhouse_ratings_on_player_id_and_role", unique: true
    t.index ["player_id"], name: "index_player_inhouse_ratings_on_player_id"
  end

  create_table "player_match_stats", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "match_id", null: false
    t.uuid "player_id", null: false
    t.string "champion", null: false
    t.string "role"
    t.string "lane"
    t.integer "kills", default: 0
    t.integer "deaths", default: 0
    t.integer "assists", default: 0
    t.integer "double_kills", default: 0
    t.integer "triple_kills", default: 0
    t.integer "quadra_kills", default: 0
    t.integer "penta_kills", default: 0
    t.integer "largest_killing_spree"
    t.integer "largest_multi_kill"
    t.integer "cs", default: 0
    t.decimal "cs_per_min", precision: 5, scale: 2
    t.integer "gold_earned"
    t.decimal "gold_per_min", precision: 8, scale: 2
    t.decimal "gold_share", precision: 5, scale: 2
    t.integer "damage_dealt_champions"
    t.integer "damage_dealt_total"
    t.integer "damage_dealt_objectives"
    t.integer "damage_taken"
    t.integer "damage_mitigated"
    t.decimal "damage_share", precision: 5, scale: 2
    t.integer "vision_score"
    t.integer "wards_placed"
    t.integer "wards_destroyed"
    t.integer "control_wards_purchased"
    t.decimal "kill_participation", precision: 5, scale: 2
    t.boolean "first_blood", default: false
    t.boolean "first_tower", default: false
    t.integer "items", default: [], array: true
    t.integer "item_build_order", default: [], array: true
    t.integer "trinket"
    t.string "summoner_spell_1"
    t.string "summoner_spell_2"
    t.string "primary_rune_tree"
    t.string "secondary_rune_tree"
    t.integer "runes", default: [], array: true
    t.integer "healing_done"
    t.decimal "performance_score", precision: 5, scale: 2
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "neutral_minions_killed"
    t.integer "objectives_stolen", default: 0
    t.integer "turret_plates_destroyed"
    t.integer "crowd_control_score"
    t.integer "total_time_dead"
    t.integer "damage_to_turrets"
    t.integer "damage_shielded_teammates"
    t.integer "healing_to_teammates"
    t.integer "cs_at_10"
    t.integer "spell_q_casts"
    t.integer "spell_w_casts"
    t.integer "spell_e_casts"
    t.integer "spell_r_casts"
    t.integer "summoner_spell_1_casts"
    t.integer "summoner_spell_2_casts"
    t.jsonb "pings", default: {}
    t.string "opponent_champion"
    t.index ["champion"], name: "index_player_match_stats_on_champion"
    t.index ["crowd_control_score"], name: "idx_pms_cc_score"
    t.index ["match_id", "player_id"], name: "idx_player_stats_match_player_agg", comment: "Otimiza agregações de estatísticas (SUM kills/deaths/assists)"
    t.index ["objectives_stolen"], name: "idx_pms_objectives_stolen", where: "(objectives_stolen > 0)"
    t.index ["opponent_champion"], name: "idx_pms_opponent_champion"
    t.index ["player_id", "champion", "created_at"], name: "idx_pms_player_champion_date"
    t.index ["player_id", "champion"], name: "idx_pms_player_champion"
    t.index ["player_id", "cs_per_min"], name: "idx_pms_player_cs_per_min"
    t.index ["player_id", "match_id"], name: "index_player_match_stats_on_player_id_and_match_id", unique: true
    t.index ["player_id", "performance_score"], name: "idx_pms_player_performance_score"
    t.index ["player_id", "vision_score"], name: "idx_pms_player_vision_score"
    t.index ["player_id"], name: "index_player_match_stats_on_player_id"
  end

  create_table "player_rank_snapshots", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "player_id", null: false
    t.string "queue_type", default: "RANKED_SOLO_5x5", null: false, comment: "Riot queue type: RANKED_SOLO_5x5 | RANKED_FLEX_SR"
    t.string "tier", comment: "e.g. GRANDMASTER, CHALLENGER, MASTER"
    t.string "rank", comment: "e.g. I, II, III, IV (null for apex tiers)"
    t.integer "league_points", default: 0, null: false
    t.integer "wins", default: 0, null: false
    t.integer "losses", default: 0, null: false
    t.date "recorded_on", null: false, comment: "Date the snapshot was taken (one per player per queue per day)"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id", "queue_type", "recorded_on"], name: "idx_player_rank_snapshots_unique", unique: true
    t.index ["player_id", "recorded_on"], name: "index_player_rank_snapshots_on_player_id_and_recorded_on"
    t.index ["player_id"], name: "index_player_rank_snapshots_on_player_id"
  end

  create_table "players", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id"
    t.string "summoner_name", null: false
    t.string "real_name"
    t.string "role", null: false
    t.string "country"
    t.date "birth_date"
    t.string "status", default: "active"
    t.string "riot_puuid"
    t.string "riot_summoner_id"
    t.string "riot_account_id"
    t.integer "profile_icon_id"
    t.integer "summoner_level"
    t.string "solo_queue_tier"
    t.string "solo_queue_rank"
    t.integer "solo_queue_lp"
    t.integer "solo_queue_wins"
    t.integer "solo_queue_losses"
    t.string "flex_queue_tier"
    t.string "flex_queue_rank"
    t.integer "flex_queue_lp"
    t.string "peak_tier"
    t.string "peak_rank"
    t.string "peak_season"
    t.integer "jersey_number"
    t.text "champion_pool", default: [], array: true
    t.string "preferred_role_secondary"
    t.text "playstyle_tags", default: [], array: true
    t.string "twitter_handle"
    t.string "twitch_channel"
    t.string "instagram_handle"
    t.text "notes"
    t.jsonb "metadata", default: {}
    t.datetime "last_sync_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "sync_status"
    t.string "region"
    t.string "avatar_url"
    t.string "kick_url"
    t.string "professional_name", comment: "Professional/competitive IGN used in tournaments (e.g., \"Titan\" for paiN Gaming)"
    t.datetime "deleted_at", comment: "Soft delete timestamp - when player was removed from team"
    t.text "removed_reason", comment: "Reason for removal (contract end, transfer, etc)"
    t.uuid "previous_organization_id", comment: "Previous organization if transferred"
    t.string "player_email", comment: "Email for player individual access"
    t.string "player_password_digest", comment: "Password hash for player authentication"
    t.datetime "last_login_at", comment: "Last login timestamp for player access"
    t.boolean "player_access_enabled", default: false, comment: "Enable/disable individual player access"
    t.string "access_token_jti", comment: "JWT token identifier for player session"
    t.string "discord_user_id"
    t.uuid "scouted_from_id"
    t.jsonb "scouting_data_snapshot", default: {}, null: false
    t.string "source_app", default: "arena_br", null: false
    t.string "line", default: "main", null: false
    t.string "residency", comment: "Import slot classification: resident | non_resident | na_resident | americas_resident | native_resident. See Constants::Player::RESIDENCIES."
    t.string "player_type", default: "player", null: false, comment: "Record type: player | coach | analyst | manager"
    t.string "staff_role", comment: "Coaching staff function when player_type != player (e.g. head_coach, assistant_coach, analyst)"
    t.index ["deleted_at"], name: "index_players_on_deleted_at", comment: "Index for soft delete queries"
    t.index ["discord_user_id"], name: "index_players_on_discord_user_id", unique: true, where: "(discord_user_id IS NOT NULL)"
    t.index ["line"], name: "index_players_on_line"
    t.index ["organization_id", "deleted_at", "status"], name: "idx_players_org_deleted_status"
    t.index ["organization_id", "deleted_at"], name: "idx_players_org_deleted"
    t.index ["organization_id", "deleted_at"], name: "idx_players_org_deleted_active", where: "(deleted_at IS NULL)", comment: "Índice parcial para COUNT de players ativos"
    t.index ["organization_id", "last_sync_at"], name: "idx_players_org_last_sync"
    t.index ["organization_id", "role"], name: "index_players_on_org_and_role"
    t.index ["organization_id", "sync_status"], name: "idx_players_org_sync_status"
    t.index ["organization_id"], name: "index_players_on_organization_id"
    t.index ["player_access_enabled"], name: "index_players_on_player_access_enabled", comment: "Quick lookup for players with access enabled"
    t.index ["player_email"], name: "index_players_on_player_email", unique: true, where: "(player_email IS NOT NULL)", comment: "Unique email for player access"
    t.index ["player_type"], name: "index_players_on_player_type"
    t.index ["previous_organization_id"], name: "index_players_on_previous_organization_id", comment: "Track player transfers"
    t.index ["professional_name"], name: "index_players_on_professional_name"
    t.index ["residency"], name: "index_players_on_residency"
    t.index ["riot_puuid"], name: "index_players_on_riot_puuid", unique: true
    t.index ["role"], name: "index_players_on_role"
    t.index ["scouted_from_id"], name: "index_players_on_scouted_from_id"
    t.index ["source_app"], name: "index_players_on_source_app"
    t.index ["status"], name: "index_players_on_status"
    t.index ["summoner_name"], name: "index_players_on_summoner_name"
  end

  create_table "roster_season_slots", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "roster_season_snapshot_id", null: false
    t.uuid "player_id", null: false
    t.string "role", comment: "Lane role at the time of the snapshot"
    t.string "line", default: "main", null: false, comment: "main | academy | reserve | two_way"
    t.string "transfer_status", comment: "Optional: joined | departed | loan"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "idx_roster_slots_player"
    t.index ["roster_season_snapshot_id"], name: "idx_roster_slots_snapshot"
  end

  create_table "roster_season_snapshots", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.string "season", null: false, comment: "e.g. '2026 Split 1' or 'CBLOL 2026 Split 1'"
    t.date "snapshot_date", null: false
    t.uuid "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_roster_season_snapshots_on_created_by_id"
    t.index ["organization_id", "season"], name: "idx_roster_snapshots_org_season"
    t.index ["organization_id"], name: "index_roster_season_snapshots_on_organization_id"
  end

  create_table "saved_builds", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.uuid "created_by_id"
    t.string "champion", null: false
    t.string "role"
    t.string "patch_version"
    t.integer "items", default: [], array: true
    t.integer "item_build_order", default: [], array: true
    t.integer "trinket"
    t.integer "runes", default: [], array: true
    t.string "primary_rune_tree"
    t.string "secondary_rune_tree"
    t.string "summoner_spell_1"
    t.string "summoner_spell_2"
    t.decimal "win_rate", precision: 5, scale: 2, default: "0.0"
    t.integer "games_played", default: 0, null: false
    t.decimal "average_kda", precision: 5, scale: 2, default: "0.0"
    t.decimal "average_cs_per_min", precision: 5, scale: 2, default: "0.0"
    t.decimal "average_damage_share", precision: 5, scale: 2, default: "0.0"
    t.string "title"
    t.text "notes"
    t.boolean "is_public", default: false, null: false
    t.string "data_source", default: "manual", null: false
    t.string "items_fingerprint"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_saved_builds_on_created_by_id"
    t.index ["organization_id", "champion", "role", "items_fingerprint"], name: "idx_saved_builds_aggregated_unique", unique: true, where: "((data_source)::text = 'aggregated'::text)"
    t.index ["organization_id", "champion", "role"], name: "idx_saved_builds_org_champion_role"
    t.index ["organization_id", "is_public"], name: "idx_saved_builds_org_public"
    t.index ["organization_id", "patch_version"], name: "idx_saved_builds_org_patch"
    t.index ["organization_id", "win_rate"], name: "idx_saved_builds_win_rate"
    t.index ["organization_id"], name: "index_saved_builds_on_organization_id"
  end

  create_table "schedules", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.string "title", null: false
    t.text "description"
    t.string "event_type", null: false
    t.datetime "start_time", precision: nil, null: false
    t.datetime "end_time", precision: nil, null: false
    t.string "timezone"
    t.boolean "all_day", default: false
    t.uuid "match_id"
    t.string "opponent_name"
    t.string "location"
    t.string "meeting_url"
    t.uuid "required_players", default: [], array: true
    t.uuid "optional_players", default: [], array: true
    t.string "status", default: "scheduled"
    t.text "tags", default: [], array: true
    t.string "color"
    t.boolean "is_recurring", default: false
    t.string "recurrence_rule"
    t.date "recurrence_end_date"
    t.integer "reminder_minutes", default: [], array: true
    t.uuid "created_by_id"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_schedules_on_created_by_id"
    t.index ["event_type"], name: "index_schedules_on_event_type"
    t.index ["match_id"], name: "index_schedules_on_match_id"
    t.index ["organization_id", "event_type"], name: "idx_schedules_org_event_type"
    t.index ["organization_id", "start_time", "event_type"], name: "idx_schedules_org_time_type", comment: "Otimiza queries de próximos eventos"
    t.index ["organization_id"], name: "index_schedules_on_organization_id"
    t.index ["start_time"], name: "index_schedules_on_start_time"
    t.index ["status"], name: "index_schedules_on_status"
  end

  create_table "scouting_targets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "summoner_name", null: false
    t.string "region", null: false
    t.string "riot_puuid"
    t.string "role", null: false
    t.string "current_tier"
    t.string "current_rank"
    t.integer "current_lp"
    t.text "champion_pool", default: [], array: true
    t.string "playstyle"
    t.text "strengths", default: [], array: true
    t.text "weaknesses", default: [], array: true
    t.jsonb "recent_performance", default: {}
    t.string "performance_trend"
    t.string "email"
    t.string "phone"
    t.string "discord_username"
    t.string "twitter_handle"
    t.string "status", default: "watching"
    t.text "notes"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "age"
    t.string "real_name"
    t.string "avatar_url"
    t.integer "profile_icon_id"
    t.string "peak_tier"
    t.string "peak_rank"
    t.datetime "last_api_sync_at"
    t.jsonb "season_history", default: []
    t.string "professional_name", comment: "Competitive tournament IGN as indexed in Leaguepedia/ES. Join key for competitive_profile lookups. Distinct from summoner_name (Riot ID) which diverges from historical tournament names."
    t.index ["current_tier"], name: "index_scouting_targets_on_current_tier"
    t.index ["professional_name"], name: "idx_scouting_targets_professional_name", where: "(professional_name IS NOT NULL)"
    t.index ["region"], name: "index_scouting_targets_on_region"
    t.index ["riot_puuid"], name: "index_scouting_targets_on_riot_puuid", unique: true, where: "(riot_puuid IS NOT NULL)"
    t.index ["role"], name: "index_scouting_targets_on_role"
    t.index ["status"], name: "index_scouting_targets_on_status"
    t.index ["summoner_name"], name: "index_scouting_targets_on_summoner_name"
  end

  create_table "scouting_watchlists", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.uuid "scouting_target_id", null: false
    t.uuid "added_by_id", null: false
    t.uuid "assigned_to_id"
    t.string "priority", default: "medium", null: false
    t.string "status", default: "watching", null: false
    t.text "notes"
    t.datetime "last_reviewed"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["added_by_id"], name: "index_scouting_watchlists_on_added_by_id"
    t.index ["assigned_to_id"], name: "index_scouting_watchlists_on_assigned_to_id"
    t.index ["last_reviewed"], name: "index_scouting_watchlists_on_last_reviewed"
    t.index ["organization_id", "scouting_target_id"], name: "index_watchlists_on_org_and_target", unique: true
    t.index ["organization_id"], name: "index_scouting_watchlists_on_organization_id"
    t.index ["priority"], name: "index_scouting_watchlists_on_priority"
    t.index ["scouting_target_id"], name: "index_scouting_watchlists_on_scouting_target_id"
    t.index ["status"], name: "index_scouting_watchlists_on_status"
  end

  create_table "scrim_messages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "scrim_id", null: false
    t.uuid "user_id", null: false
    t.uuid "organization_id", null: false
    t.text "content", null: false
    t.boolean "deleted", default: false, null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_scrim_messages_on_organization_id"
    t.index ["scrim_id", "created_at"], name: "index_scrim_messages_on_scrim_id_and_created_at"
    t.index ["scrim_id"], name: "index_scrim_messages_on_scrim_id"
    t.index ["user_id"], name: "index_scrim_messages_on_user_id"
  end

  create_table "scrim_requests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "requesting_organization_id", null: false
    t.uuid "target_organization_id", null: false
    t.uuid "requesting_scrim_id"
    t.uuid "target_scrim_id"
    t.uuid "availability_window_id"
    t.string "status", default: "pending", null: false
    t.string "game", default: "league_of_legends", null: false
    t.text "message"
    t.datetime "proposed_at"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "games_planned", default: 3
    t.string "draft_type"
    t.index ["expires_at"], name: "index_scrim_requests_on_expires_at"
    t.index ["requesting_organization_id", "status"], name: "index_scrim_requests_on_requesting_organization_id_and_status"
    t.index ["requesting_organization_id"], name: "index_scrim_requests_on_requesting_organization_id"
    t.index ["status"], name: "index_scrim_requests_on_status"
    t.index ["target_organization_id", "status"], name: "index_scrim_requests_on_target_organization_id_and_status"
    t.index ["target_organization_id"], name: "index_scrim_requests_on_target_organization_id"
  end

  create_table "scrim_result_reports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "scrim_request_id", null: false
    t.uuid "organization_id", null: false
    t.string "game_outcomes", default: [], array: true
    t.string "status", default: "pending", null: false
    t.integer "attempt_count", default: 0, null: false
    t.datetime "reported_at"
    t.datetime "deadline_at", null: false
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_scrim_result_reports_on_organization_id"
    t.index ["scrim_request_id", "organization_id"], name: "idx_scrim_result_reports_unique_per_org", unique: true
    t.index ["scrim_request_id"], name: "index_scrim_result_reports_on_scrim_request_id"
  end

  create_table "scrims", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.uuid "match_id"
    t.uuid "opponent_team_id"
    t.datetime "scheduled_at"
    t.string "scrim_type"
    t.string "focus_area"
    t.text "pre_game_notes"
    t.text "post_game_notes"
    t.boolean "is_confidential", default: true
    t.string "visibility"
    t.integer "games_planned"
    t.integer "games_completed"
    t.jsonb "game_results", default: []
    t.jsonb "objectives", default: {}
    t.jsonb "outcomes", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source", default: "internal"
    t.uuid "scrim_request_id"
    t.string "draft_type"
    t.string "game", default: "league_of_legends", null: false
    t.index ["game", "visibility", "scheduled_at"], name: "idx_scrims_game_visibility_scheduled"
    t.index ["game"], name: "index_scrims_on_game"
    t.index ["match_id"], name: "index_scrims_on_match_id"
    t.index ["opponent_team_id"], name: "index_scrims_on_opponent_team_id"
    t.index ["organization_id", "scheduled_at"], name: "idx_scrims_org_scheduled"
    t.index ["organization_id"], name: "index_scrims_on_organization_id"
    t.index ["scheduled_at"], name: "index_scrims_on_scheduled_at"
    t.index ["scrim_request_id"], name: "index_scrims_on_scrim_request_id"
    t.index ["scrim_type"], name: "index_scrims_on_scrim_type"
    t.index ["source"], name: "index_scrims_on_source"
  end

  create_table "status_incident_updates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "status_incident_id", null: false
    t.string "status", null: false
    t.text "body", null: false
    t.uuid "created_by_user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status_incident_id"], name: "index_status_incident_updates_on_status_incident_id"
  end

  create_table "status_incidents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "title", null: false
    t.text "body", null: false
    t.string "severity", default: "minor", null: false
    t.string "status", default: "investigating", null: false
    t.string "affected_components", default: [], null: false, array: true
    t.datetime "started_at", null: false
    t.datetime "resolved_at"
    t.text "postmortem"
    t.uuid "created_by_user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["severity"], name: "index_status_incidents_on_severity"
    t.index ["started_at"], name: "index_status_incidents_on_started_at"
    t.index ["status"], name: "index_status_incidents_on_status"
  end

  create_table "status_snapshots", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "component", null: false
    t.string "status", null: false
    t.integer "response_time_ms"
    t.datetime "checked_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["component", "checked_at"], name: "idx_status_snapshots_component_checked_at", order: { checked_at: :desc }
    t.index ["component", "checked_at"], name: "index_status_snapshots_on_component_and_checked_at"
  end

  create_table "support_faqs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "question", null: false
    t.text "answer", null: false
    t.string "category", null: false
    t.string "locale", default: "pt-BR", null: false
    t.string "slug", null: false
    t.text "keywords", default: [], array: true
    t.integer "position", default: 0
    t.boolean "published", default: true
    t.integer "view_count", default: 0
    t.integer "helpful_count", default: 0
    t.integer "not_helpful_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_support_faqs_on_category"
    t.index ["locale"], name: "index_support_faqs_on_locale"
    t.index ["published", "position"], name: "index_support_faqs_on_published_and_position"
    t.index ["slug"], name: "index_support_faqs_on_slug", unique: true
  end

  create_table "support_ticket_messages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "support_ticket_id", null: false
    t.uuid "user_id", null: false
    t.text "content", null: false
    t.string "message_type", default: "user", null: false
    t.boolean "is_internal", default: false
    t.jsonb "attachments", default: []
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["message_type"], name: "index_support_ticket_messages_on_message_type"
    t.index ["support_ticket_id", "created_at"], name: "idx_on_support_ticket_id_created_at_0d70c2b287"
    t.index ["support_ticket_id"], name: "index_support_ticket_messages_on_support_ticket_id"
    t.index ["user_id"], name: "index_support_ticket_messages_on_user_id"
  end

  create_table "support_tickets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "organization_id", null: false
    t.uuid "assigned_to_id"
    t.string "subject", null: false
    t.text "description", null: false
    t.string "category", null: false
    t.string "priority", default: "medium", null: false
    t.string "status", default: "open", null: false
    t.string "page_url"
    t.jsonb "context_data", default: {}
    t.boolean "chatbot_attempted", default: false
    t.jsonb "chatbot_suggestions", default: []
    t.datetime "first_response_at"
    t.datetime "resolved_at"
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["assigned_to_id", "status"], name: "index_support_tickets_on_assigned_to_id_and_status"
    t.index ["assigned_to_id"], name: "index_support_tickets_on_assigned_to_id"
    t.index ["category"], name: "index_support_tickets_on_category"
    t.index ["deleted_at"], name: "index_support_tickets_on_deleted_at"
    t.index ["organization_id", "status"], name: "index_support_tickets_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_support_tickets_on_organization_id"
    t.index ["priority"], name: "index_support_tickets_on_priority"
    t.index ["status"], name: "index_support_tickets_on_status"
    t.index ["user_id"], name: "index_support_tickets_on_user_id"
  end

  create_table "tactical_boards", force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.uuid "match_id"
    t.uuid "scrim_id"
    t.string "title", null: false
    t.jsonb "map_state", default: {}
    t.jsonb "annotations", default: []
    t.string "game_time"
    t.uuid "created_by_id", null: false
    t.uuid "updated_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_tactical_boards_on_created_by_id"
    t.index ["match_id"], name: "index_tactical_boards_on_match_id"
    t.index ["organization_id", "created_at"], name: "index_tactical_boards_on_organization_id_and_created_at"
    t.index ["organization_id"], name: "index_tactical_boards_on_organization_id"
    t.index ["scrim_id"], name: "index_tactical_boards_on_scrim_id"
    t.index ["updated_by_id"], name: "index_tactical_boards_on_updated_by_id"
  end

  create_table "team_checkins", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tournament_match_id", null: false
    t.uuid "tournament_team_id", null: false
    t.uuid "checked_in_by_id"
    t.datetime "checked_in_at", default: -> { "now()" }, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["checked_in_by_id"], name: "index_team_checkins_on_checked_in_by_id"
    t.index ["tournament_match_id", "tournament_team_id"], name: "idx_team_checkins_unique_per_team", unique: true
    t.index ["tournament_match_id"], name: "index_team_checkins_on_tournament_match_id"
    t.index ["tournament_team_id"], name: "index_team_checkins_on_tournament_team_id"
  end

  create_table "team_goals", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.uuid "player_id"
    t.string "title", null: false
    t.text "description"
    t.string "category"
    t.string "metric_type"
    t.decimal "target_value", precision: 10, scale: 2
    t.decimal "current_value", precision: 10, scale: 2
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.string "status", default: "active"
    t.integer "progress", default: 0
    t.uuid "assigned_to_id"
    t.uuid "created_by_id"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_to_id"], name: "index_team_goals_on_assigned_to_id"
    t.index ["category"], name: "index_team_goals_on_category"
    t.index ["created_by_id"], name: "index_team_goals_on_created_by_id"
    t.index ["organization_id", "status"], name: "idx_team_goals_org_status", comment: "Otimiza COUNT de goals por status"
    t.index ["organization_id"], name: "index_team_goals_on_organization_id"
    t.index ["player_id"], name: "index_team_goals_on_player_id"
    t.index ["status"], name: "index_team_goals_on_status"
  end

  create_table "token_blacklists", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "jti", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_token_blacklists_on_expires_at"
    t.index ["jti"], name: "index_token_blacklists_on_jti", unique: true
  end

  create_table "tournament_matches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tournament_id", null: false
    t.uuid "next_match_winner_id"
    t.uuid "next_match_loser_id"
    t.uuid "team_a_id"
    t.uuid "team_b_id"
    t.integer "team_a_score", default: 0, null: false
    t.integer "team_b_score", default: 0, null: false
    t.uuid "winner_id"
    t.uuid "loser_id"
    t.string "bracket_side", null: false
    t.string "round_label", null: false
    t.integer "round_order", null: false
    t.integer "match_number", null: false
    t.integer "bo_format", default: 3, null: false
    t.string "status", default: "scheduled", null: false
    t.datetime "scheduled_at"
    t.datetime "checkin_opens_at"
    t.datetime "checkin_deadline_at"
    t.datetime "wo_deadline_at"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["loser_id"], name: "index_tournament_matches_on_loser_id"
    t.index ["next_match_loser_id"], name: "index_tournament_matches_on_next_match_loser_id"
    t.index ["next_match_winner_id"], name: "index_tournament_matches_on_next_match_winner_id"
    t.index ["status"], name: "index_tournament_matches_on_status"
    t.index ["team_a_id"], name: "index_tournament_matches_on_team_a_id"
    t.index ["team_b_id"], name: "index_tournament_matches_on_team_b_id"
    t.index ["tournament_id"], name: "index_tournament_matches_on_tournament_id"
    t.index ["winner_id"], name: "index_tournament_matches_on_winner_id"
  end

  create_table "tournament_roster_snapshots", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tournament_team_id", null: false
    t.uuid "player_id", null: false
    t.string "summoner_name", null: false
    t.string "role"
    t.string "position", null: false
    t.datetime "locked_at", default: -> { "now()" }, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_tournament_roster_snapshots_on_player_id"
    t.index ["tournament_team_id", "player_id"], name: "idx_roster_snapshots_unique_per_player", unique: true
    t.index ["tournament_team_id"], name: "index_tournament_roster_snapshots_on_tournament_team_id"
  end

  create_table "tournament_teams", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "tournament_id", null: false
    t.uuid "organization_id", null: false
    t.string "team_name", null: false
    t.string "team_tag", null: false
    t.string "logo_url"
    t.string "status", default: "pending", null: false
    t.integer "seed"
    t.string "bracket_side"
    t.datetime "enrolled_at", default: -> { "now()" }, null: false
    t.datetime "approved_at"
    t.datetime "rejected_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_tournament_teams_on_organization_id"
    t.index ["status"], name: "index_tournament_teams_on_status"
    t.index ["tournament_id", "organization_id"], name: "idx_tournament_teams_unique_per_org", unique: true
    t.index ["tournament_id"], name: "index_tournament_teams_on_tournament_id"
  end

  create_table "tournaments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "game", default: "league_of_legends", null: false
    t.string "format", default: "double_elimination", null: false
    t.string "status", default: "draft", null: false
    t.integer "max_teams", default: 16, null: false
    t.integer "entry_fee_cents", default: 0, null: false
    t.integer "prize_pool_cents", default: 0, null: false
    t.integer "bo_format", default: 3, null: false
    t.string "current_round_label"
    t.text "rules"
    t.datetime "registration_closes_at"
    t.datetime "scheduled_start_at"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["scheduled_start_at"], name: "index_tournaments_on_scheduled_start_at"
    t.index ["status"], name: "index_tournaments_on_status"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "full_name"
    t.string "role", null: false
    t.string "avatar_url"
    t.string "timezone"
    t.string "language"
    t.boolean "notifications_enabled", default: true
    t.jsonb "notification_preferences", default: {}
    t.datetime "last_login_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "discord_user_id"
    t.string "source_app", default: "prostaff", null: false
    t.index ["discord_user_id"], name: "index_users_on_discord_user_id", unique: true, where: "(discord_user_id IS NOT NULL)"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
    t.index ["role"], name: "index_users_on_role"
    t.index ["source_app"], name: "index_users_on_source_app"
  end

  create_table "vod_reviews", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.uuid "match_id"
    t.string "title", null: false
    t.text "description"
    t.string "review_type"
    t.datetime "review_date", precision: nil
    t.string "video_url", null: false
    t.string "thumbnail_url"
    t.integer "duration"
    t.boolean "is_public", default: false
    t.string "share_link"
    t.uuid "shared_with_players", default: [], array: true
    t.uuid "reviewer_id"
    t.string "status", default: "draft"
    t.text "tags", default: [], array: true
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["match_id"], name: "index_vod_reviews_on_match_id"
    t.index ["organization_id"], name: "index_vod_reviews_on_organization_id"
    t.index ["reviewer_id"], name: "index_vod_reviews_on_reviewer_id"
    t.index ["share_link"], name: "index_vod_reviews_on_share_link", unique: true
    t.index ["status"], name: "index_vod_reviews_on_status"
  end

  create_table "vod_timestamps", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "vod_review_id", null: false
    t.integer "timestamp_seconds", null: false
    t.string "title", null: false
    t.text "description"
    t.string "category"
    t.string "importance", default: "normal"
    t.string "target_type"
    t.uuid "target_player_id"
    t.uuid "created_by_id"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_vod_timestamps_on_category"
    t.index ["created_by_id"], name: "index_vod_timestamps_on_created_by_id"
    t.index ["importance"], name: "index_vod_timestamps_on_importance"
    t.index ["target_player_id"], name: "index_vod_timestamps_on_target_player_id"
    t.index ["timestamp_seconds"], name: "index_vod_timestamps_on_timestamp_seconds"
    t.index ["vod_review_id"], name: "index_vod_timestamps_on_vod_review_id"
  end

  add_foreign_key "audit_logs", "organizations"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "availability_windows", "organizations"
  add_foreign_key "budget_allocations", "organizations", name: "fk_budget_allocs_organization"
  add_foreign_key "budget_allocations", "users", column: "created_by_id", name: "fk_budget_allocs_created_by"
  add_foreign_key "champion_pools", "players"
  add_foreign_key "competitive_matches", "matches"
  add_foreign_key "competitive_matches", "opponent_teams"
  add_foreign_key "competitive_matches", "organizations"
  add_foreign_key "contract_bonuses", "contracts", name: "fk_contract_bonuses_contract"
  add_foreign_key "contract_bonuses", "organizations", name: "fk_contract_bonuses_organization"
  add_foreign_key "contracts", "contracts", column: "renewed_from_id", name: "fk_contracts_renewed_from"
  add_foreign_key "contracts", "organizations", name: "fk_contracts_organization"
  add_foreign_key "contracts", "players", name: "fk_contracts_player"
  add_foreign_key "contracts", "users", column: "created_by_id", name: "fk_contracts_created_by"
  add_foreign_key "contracts", "users", column: "updated_by_id", name: "fk_contracts_updated_by"
  add_foreign_key "draft_plans", "organizations"
  add_foreign_key "draft_plans", "users", column: "created_by_id"
  add_foreign_key "draft_plans", "users", column: "updated_by_id"
  add_foreign_key "draft_simulations", "organizations", on_delete: :cascade
  add_foreign_key "expenses", "budget_allocations", name: "fk_expenses_budget_allocation"
  add_foreign_key "expenses", "organizations", name: "fk_expenses_organization"
  add_foreign_key "expenses", "players", name: "fk_expenses_player"
  add_foreign_key "expenses", "users", column: "approved_by_id", name: "fk_expenses_approved_by"
  add_foreign_key "expenses", "users", column: "created_by_id", name: "fk_expenses_created_by"
  add_foreign_key "feedback_votes", "feedbacks"
  add_foreign_key "feedback_votes", "users"
  add_foreign_key "feedbacks", "organizations"
  add_foreign_key "feedbacks", "users"
  add_foreign_key "inhouse_participations", "inhouses"
  add_foreign_key "inhouse_participations", "players"
  add_foreign_key "inhouse_queue_entries", "inhouse_queues"
  add_foreign_key "inhouse_queue_entries", "players"
  add_foreign_key "inhouse_queues", "organizations"
  add_foreign_key "inhouse_queues", "users", column: "created_by_user_id"
  add_foreign_key "inhouses", "organizations"
  add_foreign_key "inhouses", "players", column: "blue_captain_id"
  add_foreign_key "inhouses", "players", column: "red_captain_id"
  add_foreign_key "inhouses", "users", column: "created_by_user_id"
  add_foreign_key "match_reports", "tournament_matches"
  add_foreign_key "match_reports", "tournament_teams"
  add_foreign_key "match_reports", "users", column: "reported_by_user_id"
  add_foreign_key "matches", "organizations"
  add_foreign_key "messages", "organizations"
  add_foreign_key "notifications", "users"
  add_foreign_key "password_reset_tokens", "players", on_delete: :cascade
  add_foreign_key "password_reset_tokens", "users"
  add_foreign_key "player_inhouse_ratings", "organizations"
  add_foreign_key "player_inhouse_ratings", "players"
  add_foreign_key "player_match_stats", "matches"
  add_foreign_key "player_match_stats", "players"
  add_foreign_key "player_rank_snapshots", "players"
  add_foreign_key "players", "organizations"
  add_foreign_key "players", "organizations", column: "previous_organization_id", on_delete: :nullify
  add_foreign_key "players", "scouting_targets", column: "scouted_from_id", on_delete: :nullify
  add_foreign_key "roster_season_slots", "players"
  add_foreign_key "roster_season_slots", "roster_season_snapshots"
  add_foreign_key "roster_season_snapshots", "organizations"
  add_foreign_key "roster_season_snapshots", "users", column: "created_by_id"
  add_foreign_key "saved_builds", "organizations"
  add_foreign_key "saved_builds", "users", column: "created_by_id"
  add_foreign_key "schedules", "matches"
  add_foreign_key "schedules", "organizations"
  add_foreign_key "schedules", "users", column: "created_by_id"
  add_foreign_key "scouting_watchlists", "organizations"
  add_foreign_key "scouting_watchlists", "scouting_targets"
  add_foreign_key "scouting_watchlists", "users", column: "added_by_id"
  add_foreign_key "scouting_watchlists", "users", column: "assigned_to_id"
  add_foreign_key "scrim_messages", "organizations"
  add_foreign_key "scrim_messages", "scrims"
  add_foreign_key "scrim_messages", "users"
  add_foreign_key "scrim_requests", "organizations", column: "requesting_organization_id"
  add_foreign_key "scrim_requests", "organizations", column: "target_organization_id"
  add_foreign_key "scrim_result_reports", "organizations"
  add_foreign_key "scrim_result_reports", "scrim_requests"
  add_foreign_key "scrims", "matches"
  add_foreign_key "scrims", "opponent_teams"
  add_foreign_key "scrims", "organizations"
  add_foreign_key "status_incident_updates", "status_incidents"
  add_foreign_key "status_incident_updates", "users", column: "created_by_user_id"
  add_foreign_key "status_incidents", "users", column: "created_by_user_id"
  add_foreign_key "support_ticket_messages", "support_tickets"
  add_foreign_key "support_ticket_messages", "users"
  add_foreign_key "support_tickets", "organizations"
  add_foreign_key "support_tickets", "users"
  add_foreign_key "support_tickets", "users", column: "assigned_to_id"
  add_foreign_key "tactical_boards", "matches"
  add_foreign_key "tactical_boards", "organizations"
  add_foreign_key "tactical_boards", "scrims"
  add_foreign_key "tactical_boards", "users", column: "created_by_id"
  add_foreign_key "tactical_boards", "users", column: "updated_by_id"
  add_foreign_key "team_checkins", "tournament_matches"
  add_foreign_key "team_checkins", "tournament_teams"
  add_foreign_key "team_checkins", "users", column: "checked_in_by_id"
  add_foreign_key "team_goals", "organizations"
  add_foreign_key "team_goals", "players"
  add_foreign_key "team_goals", "users", column: "assigned_to_id"
  add_foreign_key "team_goals", "users", column: "created_by_id"
  add_foreign_key "tournament_matches", "tournament_teams", column: "loser_id"
  add_foreign_key "tournament_matches", "tournament_teams", column: "team_a_id"
  add_foreign_key "tournament_matches", "tournament_teams", column: "team_b_id"
  add_foreign_key "tournament_matches", "tournament_teams", column: "winner_id"
  add_foreign_key "tournament_matches", "tournaments"
  add_foreign_key "tournament_roster_snapshots", "players"
  add_foreign_key "tournament_roster_snapshots", "tournament_teams"
  add_foreign_key "tournament_teams", "organizations"
  add_foreign_key "tournament_teams", "tournaments"
  add_foreign_key "users", "organizations"
  add_foreign_key "vod_reviews", "matches"
  add_foreign_key "vod_reviews", "organizations"
  add_foreign_key "vod_reviews", "users", column: "reviewer_id"
  add_foreign_key "vod_timestamps", "players", column: "target_player_id"
  add_foreign_key "vod_timestamps", "users", column: "created_by_id"
  add_foreign_key "vod_timestamps", "vod_reviews"
end
