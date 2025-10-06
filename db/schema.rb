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

ActiveRecord::Schema[7.1].define(version: 2024_10_01_000001) do
  create_schema "auth"
  create_schema "extensions"
  create_schema "graphql"
  create_schema "graphql_public"
  create_schema "pgbouncer"
  create_schema "realtime"
  create_schema "storage"
  create_schema "supabase_migrations"
  create_schema "vault"

  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_graphql"
  enable_extension "pg_stat_statements"
  enable_extension "pgcrypto"
  enable_extension "plpgsql"
  enable_extension "supabase_vault"
  enable_extension "uuid-ossp"

  create_table "audit_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id"
    t.uuid "user_id"
    t.string "action", limit: 50, null: false
    t.string "entity_type", limit: 30, null: false
    t.uuid "entity_id"
    t.jsonb "old_values"
    t.jsonb "new_values"
    t.inet "ip_address"
    t.text "user_agent"
    t.timestamptz "created_at", default: -> { "now()" }
    t.index ["created_at"], name: "idx_audit_logs_created", order: :desc
    t.index ["entity_type", "entity_id"], name: "idx_audit_logs_entity"
    t.index ["organization_id"], name: "idx_audit_logs_organization"
    t.index ["user_id"], name: "idx_audit_logs_user"
  end

  create_table "champion_pools", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "player_id", null: false
    t.string "champion", limit: 50, null: false
    t.integer "mastery_level", default: 1
    t.integer "games_played", default: 0
    t.integer "games_won", default: 0
    t.decimal "average_kda", precision: 5, scale: 2
    t.decimal "average_cs_per_min", precision: 5, scale: 2
    t.decimal "average_damage_share", precision: 5, scale: 2
    t.boolean "is_comfort_pick", default: false
    t.boolean "is_pocket_pick", default: false
    t.boolean "is_learning", default: false
    t.integer "priority", default: 5
    t.text "notes"
    t.timestamptz "last_played"
    t.timestamptz "created_at", default: -> { "now()" }
    t.timestamptz "updated_at", default: -> { "now()" }
    t.index ["player_id", "champion"], name: "idx_champion_pools_unique", unique: true
    t.index ["player_id"], name: "idx_champion_pools_player"
    t.check_constraint "mastery_level >= 1 AND mastery_level <= 10", name: "champion_pools_mastery_level_check"
    t.check_constraint "priority >= 1 AND priority <= 10", name: "champion_pools_priority_check"
  end

  create_table "matches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.string "match_type", limit: 20, null: false
    t.string "riot_match_id", limit: 50
    t.string "game_version", limit: 20
    t.integer "game_duration"
    t.timestamptz "game_creation"
    t.timestamptz "game_start"
    t.timestamptz "game_end"
    t.string "our_side", limit: 10
    t.string "opponent_name", limit: 100
    t.string "opponent_tag", limit: 10
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
    t.text "our_bans", array: true
    t.text "opponent_bans", array: true
    t.text "vod_url"
    t.text "replay_file_url"
    t.text "notes"
    t.text "tags", array: true
    t.jsonb "metadata", default: {}
    t.timestamptz "created_at", default: -> { "now()" }
    t.timestamptz "updated_at", default: -> { "now()" }
    t.index ["game_start"], name: "idx_matches_game_start"
    t.index ["match_type"], name: "idx_matches_type"
    t.index ["organization_id", "game_start"], name: "idx_matches_org_date", order: { game_start: :desc }
    t.index ["organization_id"], name: "idx_matches_organization"
    t.index ["victory"], name: "idx_matches_victory"
    t.check_constraint "match_type::text = ANY (ARRAY['scrim'::character varying, 'official'::character varying, 'tournament'::character varying, 'practice'::character varying]::text[])", name: "matches_match_type_check"
    t.check_constraint "our_side::text = ANY (ARRAY['blue'::character varying, 'red'::character varying]::text[])", name: "matches_our_side_check"
    t.unique_constraint ["riot_match_id"], name: "matches_riot_match_id_key"
  end

  create_table "notifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "title", limit: 200, null: false
    t.text "message", null: false
    t.string "type", limit: 20, null: false
    t.text "link_url"
    t.string "link_type", limit: 20
    t.uuid "link_id"
    t.boolean "is_read", default: false
    t.timestamptz "read_at"
    t.text "channels", array: true
    t.boolean "email_sent", default: false
    t.boolean "discord_sent", default: false
    t.jsonb "metadata", default: {}
    t.timestamptz "created_at", default: -> { "now()" }
    t.index ["created_at"], name: "idx_notifications_created", order: :desc
    t.index ["is_read"], name: "idx_notifications_read"
    t.index ["user_id", "is_read"], name: "idx_notifications_user_unread", where: "(is_read = false)"
    t.index ["user_id"], name: "idx_notifications_user"
    t.check_constraint "type::text = ANY (ARRAY['info'::character varying, 'success'::character varying, 'warning'::character varying, 'error'::character varying, 'match'::character varying, 'schedule'::character varying, 'system'::character varying]::text[])", name: "notifications_type_check"
  end

  create_table "organizations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", limit: 100, null: false
    t.string "slug", limit: 100, null: false
    t.text "logo_url"
    t.string "region", limit: 10, null: false
    t.string "tier", limit: 20, default: "amateur"
    t.string "subscription_plan", limit: 20, default: "free"
    t.string "subscription_status", limit: 20, default: "active"
    t.timestamptz "subscription_end_date"
    t.timestamptz "trial_ends_at", default: -> { "(now() + 'P14D'::interval)" }
    t.jsonb "settings", default: {}
    t.jsonb "metadata", default: {}
    t.timestamptz "created_at", default: -> { "now()" }
    t.timestamptz "updated_at", default: -> { "now()" }
    t.index ["slug"], name: "idx_organizations_slug"
    t.index ["subscription_status"], name: "idx_organizations_subscription_status"
    t.check_constraint "region::text = ANY (ARRAY['BR'::character varying, 'NA'::character varying, 'EUW'::character varying, 'EUNE'::character varying, 'KR'::character varying, 'JP'::character varying, 'LAN'::character varying, 'LAS'::character varying, 'OCE'::character varying, 'TR'::character varying, 'RU'::character varying]::text[])", name: "organizations_region_check"
    t.check_constraint "subscription_plan::text = ANY (ARRAY['free'::character varying, 'amateur'::character varying, 'semi_pro'::character varying, 'professional'::character varying, 'enterprise'::character varying]::text[])", name: "organizations_subscription_plan_check"
    t.check_constraint "subscription_status::text = ANY (ARRAY['active'::character varying, 'inactive'::character varying, 'cancelled'::character varying, 'past_due'::character varying]::text[])", name: "organizations_subscription_status_check"
    t.check_constraint "tier::text = ANY (ARRAY['amateur'::character varying, 'semi-pro'::character varying, 'professional'::character varying, 'enterprise'::character varying]::text[])", name: "organizations_tier_check"
    t.unique_constraint ["slug"], name: "organizations_slug_key"
  end

  create_table "player_match_stats", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "match_id", null: false
    t.uuid "player_id", null: false
    t.string "champion", limit: 50, null: false
    t.string "role", limit: 10
    t.string "lane", limit: 10
    t.integer "kills", default: 0
    t.integer "deaths", default: 0
    t.integer "assists", default: 0
    t.integer "cs", default: 0
    t.decimal "cs_per_min", precision: 5, scale: 2
    t.integer "gold_earned"
    t.decimal "gold_per_min", precision: 5, scale: 2
    t.integer "damage_dealt_champions"
    t.integer "damage_dealt_objectives"
    t.integer "damage_dealt_total"
    t.integer "damage_taken"
    t.integer "damage_mitigated"
    t.integer "healing_done"
    t.integer "vision_score"
    t.integer "wards_placed"
    t.integer "wards_destroyed"
    t.integer "control_wards_purchased"
    t.integer "largest_killing_spree"
    t.integer "largest_multi_kill"
    t.boolean "first_blood", default: false
    t.boolean "first_tower", default: false
    t.integer "double_kills", default: 0
    t.integer "triple_kills", default: 0
    t.integer "quadra_kills", default: 0
    t.integer "penta_kills", default: 0
    t.integer "items", array: true
    t.integer "item_build_order", array: true
    t.integer "trinket"
    t.string "summoner_spell_1", limit: 20
    t.string "summoner_spell_2", limit: 20
    t.string "primary_rune_tree", limit: 20
    t.string "secondary_rune_tree", limit: 20
    t.integer "runes", array: true
    t.decimal "kill_participation", precision: 5, scale: 2
    t.decimal "damage_share", precision: 5, scale: 2
    t.decimal "gold_share", precision: 5, scale: 2
    t.decimal "performance_score", precision: 5, scale: 2
    t.jsonb "metadata", default: {}
    t.timestamptz "created_at", default: -> { "now()" }
    t.index ["champion"], name: "idx_player_match_stats_champion"
    t.index ["match_id", "player_id"], name: "idx_player_match_unique", unique: true
    t.index ["match_id"], name: "idx_player_match_stats_match"
    t.index ["player_id", "performance_score"], name: "idx_player_stats_performance", order: { performance_score: :desc }
    t.index ["player_id"], name: "idx_player_match_stats_player"
  end

  create_table "players", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.string "summoner_name", limit: 50, null: false
    t.string "real_name", limit: 100
    t.string "role", limit: 10, null: false
    t.date "birth_date"
    t.string "country", limit: 2
    t.string "status", limit: 20, default: "active"
    t.date "contract_start_date"
    t.date "contract_end_date"
    t.decimal "salary", precision: 10, scale: 2
    t.integer "jersey_number"
    t.string "riot_puuid", limit: 100
    t.string "riot_summoner_id", limit: 100
    t.string "riot_account_id", limit: 100
    t.integer "summoner_level"
    t.integer "profile_icon_id"
    t.string "solo_queue_tier", limit: 20
    t.string "solo_queue_rank", limit: 5
    t.integer "solo_queue_lp"
    t.integer "solo_queue_wins"
    t.integer "solo_queue_losses"
    t.string "flex_queue_tier", limit: 20
    t.string "flex_queue_rank", limit: 5
    t.integer "flex_queue_lp"
    t.string "peak_tier", limit: 20
    t.string "peak_rank", limit: 5
    t.string "peak_season", limit: 20
    t.string "twitter_handle", limit: 50
    t.string "twitch_channel", limit: 50
    t.string "instagram_handle", limit: 50
    t.text "champion_pool", array: true
    t.string "preferred_role_secondary", limit: 10
    t.text "playstyle_tags", array: true
    t.text "notes"
    t.jsonb "metadata", default: {}
    t.timestamptz "created_at", default: -> { "now()" }
    t.timestamptz "updated_at", default: -> { "now()" }
    t.timestamptz "last_sync_at"
    t.index "to_tsvector('english'::regconfig, (((summoner_name)::text || ' '::text) || (COALESCE(real_name, ''::character varying))::text))", name: "idx_players_search", using: :gin
    t.index ["organization_id"], name: "idx_players_organization"
    t.index ["riot_puuid"], name: "idx_players_riot_puuid"
    t.index ["role"], name: "idx_players_role"
    t.index ["status"], name: "idx_players_status"
    t.index ["summoner_name"], name: "idx_players_summoner_name"
    t.check_constraint "role::text = ANY (ARRAY['TOP'::character varying, 'JUNGLE'::character varying, 'MID'::character varying, 'ADC'::character varying, 'SUPPORT'::character varying, 'SUB'::character varying]::text[])", name: "players_role_check"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'benched'::character varying, 'injured'::character varying, 'inactive'::character varying, 'transferred'::character varying]::text[])", name: "players_status_check"
    t.unique_constraint ["riot_puuid"], name: "players_riot_puuid_key"
  end

  create_table "schedules", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.string "title", limit: 200, null: false
    t.text "description"
    t.string "event_type", limit: 20, null: false
    t.timestamptz "start_time", null: false
    t.timestamptz "end_time", null: false
    t.boolean "all_day", default: false
    t.string "timezone", limit: 50, default: "America/Sao_Paulo"
    t.boolean "is_recurring", default: false
    t.string "recurrence_rule", limit: 200
    t.date "recurrence_end_date"
    t.uuid "required_players", array: true
    t.uuid "optional_players", array: true
    t.uuid "created_by"
    t.string "opponent_name", limit: 100
    t.uuid "match_id"
    t.text "meeting_url"
    t.string "location", limit: 200
    t.integer "reminder_minutes", array: true
    t.string "status", limit: 20, default: "scheduled"
    t.string "color", limit: 7
    t.text "tags", array: true
    t.jsonb "metadata", default: {}
    t.timestamptz "created_at", default: -> { "now()" }
    t.timestamptz "updated_at", default: -> { "now()" }
    t.index ["event_type"], name: "idx_schedules_event_type"
    t.index ["organization_id", "start_time"], name: "idx_schedules_org_time"
    t.index ["organization_id"], name: "idx_schedules_organization"
    t.index ["start_time"], name: "idx_schedules_start_time"
    t.index ["status"], name: "idx_schedules_status"
    t.check_constraint "event_type::text = ANY (ARRAY['scrim'::character varying, 'official_match'::character varying, 'practice'::character varying, 'vod_review'::character varying, 'meeting'::character varying, 'break'::character varying, 'other'::character varying]::text[])", name: "schedules_event_type_check"
    t.check_constraint "status::text = ANY (ARRAY['scheduled'::character varying, 'in_progress'::character varying, 'completed'::character varying, 'cancelled'::character varying, 'postponed'::character varying]::text[])", name: "schedules_status_check"
  end

  create_table "scouting_targets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.string "summoner_name", limit: 50, null: false
    t.string "region", limit: 10, null: false
    t.string "role", limit: 10, null: false
    t.string "riot_puuid", limit: 100
    t.string "current_tier", limit: 20
    t.string "current_rank", limit: 5
    t.integer "current_lp"
    t.string "priority", limit: 10, default: "medium"
    t.string "status", limit: 20, default: "watching"
    t.text "strengths", array: true
    t.text "weaknesses", array: true
    t.text "champion_pool", array: true
    t.string "playstyle", limit: 50
    t.string "discord_username", limit: 50
    t.string "twitter_handle", limit: 50
    t.string "email", limit: 255
    t.string "phone", limit: 20
    t.text "notes"
    t.timestamptz "last_reviewed"
    t.uuid "added_by"
    t.uuid "assigned_to"
    t.jsonb "recent_performance"
    t.string "performance_trend", limit: 10
    t.jsonb "metadata", default: {}
    t.timestamptz "created_at", default: -> { "now()" }
    t.timestamptz "updated_at", default: -> { "now()" }
    t.index "to_tsvector('english'::regconfig, (summoner_name)::text)", name: "idx_scouting_search", using: :gin
    t.index ["organization_id"], name: "idx_scouting_organization"
    t.index ["priority"], name: "idx_scouting_priority"
    t.index ["role"], name: "idx_scouting_role"
    t.index ["status"], name: "idx_scouting_status"
    t.check_constraint "performance_trend::text = ANY (ARRAY['improving'::character varying, 'stable'::character varying, 'declining'::character varying]::text[])", name: "scouting_targets_performance_trend_check"
    t.check_constraint "priority::text = ANY (ARRAY['low'::character varying, 'medium'::character varying, 'high'::character varying, 'critical'::character varying]::text[])", name: "scouting_targets_priority_check"
    t.check_constraint "status::text = ANY (ARRAY['watching'::character varying, 'contacted'::character varying, 'trialing'::character varying, 'rejected'::character varying, 'signed'::character varying]::text[])", name: "scouting_targets_status_check"
  end

  create_table "team_goals", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.uuid "player_id"
    t.string "title", limit: 200, null: false
    t.text "description"
    t.string "category", limit: 30
    t.string "metric_type", limit: 30
    t.decimal "target_value", precision: 10, scale: 2
    t.decimal "current_value", precision: 10, scale: 2
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.string "status", limit: 20, default: "active"
    t.integer "progress", default: 0
    t.uuid "created_by"
    t.uuid "assigned_to"
    t.jsonb "metadata", default: {}
    t.timestamptz "created_at", default: -> { "now()" }
    t.timestamptz "updated_at", default: -> { "now()" }
    t.index ["organization_id"], name: "idx_team_goals_organization"
    t.index ["player_id"], name: "idx_team_goals_player"
    t.index ["status"], name: "idx_team_goals_status"
    t.check_constraint "category::text = ANY (ARRAY['performance'::character varying, 'ranking'::character varying, 'champion_pool'::character varying, 'team'::character varying, 'personal'::character varying, 'other'::character varying]::text[])", name: "team_goals_category_check"
    t.check_constraint "progress >= 0 AND progress <= 100", name: "team_goals_progress_check"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'completed'::character varying, 'failed'::character varying, 'cancelled'::character varying]::text[])", name: "team_goals_status_check"
  end

  create_table "users", id: :uuid, default: nil, force: :cascade do |t|
    t.uuid "organization_id"
    t.string "email", limit: 255, null: false
    t.string "full_name", limit: 100
    t.string "display_name", limit: 50
    t.string "role", limit: 20, default: "viewer", null: false
    t.text "avatar_url"
    t.string "phone", limit: 20
    t.string "discord_id", limit: 50
    t.string "timezone", limit: 50, default: "America/Sao_Paulo"
    t.string "language", limit: 5, default: "pt-BR"
    t.boolean "notifications_enabled", default: true
    t.jsonb "notification_preferences", default: {"email" => true, "in_app" => true, "discord" => true}
    t.timestamptz "last_login"
    t.jsonb "metadata", default: {}
    t.timestamptz "created_at", default: -> { "now()" }
    t.timestamptz "updated_at", default: -> { "now()" }
    t.index ["email"], name: "idx_users_email"
    t.index ["organization_id"], name: "idx_users_organization"
    t.index ["role"], name: "idx_users_role"
    t.check_constraint "role::text = ANY (ARRAY['owner'::character varying, 'admin'::character varying, 'coach'::character varying, 'analyst'::character varying, 'player'::character varying, 'viewer'::character varying]::text[])", name: "users_role_check"
    t.unique_constraint ["email"], name: "users_email_key"
  end

  create_table "vod_reviews", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.uuid "match_id"
    t.string "title", limit: 200, null: false
    t.text "description"
    t.text "video_url", null: false
    t.text "thumbnail_url"
    t.integer "duration"
    t.uuid "reviewer_id"
    t.timestamptz "review_date", default: -> { "now()" }
    t.string "review_type", limit: 20
    t.boolean "is_public", default: false
    t.uuid "shared_with_players", array: true
    t.string "share_link", limit: 100
    t.string "status", limit: 20, default: "draft"
    t.text "tags", array: true
    t.jsonb "metadata", default: {}
    t.timestamptz "created_at", default: -> { "now()" }
    t.timestamptz "updated_at", default: -> { "now()" }
    t.index ["match_id"], name: "idx_vod_reviews_match"
    t.index ["organization_id"], name: "idx_vod_reviews_organization"
    t.index ["status"], name: "idx_vod_reviews_status"
    t.check_constraint "review_type::text = ANY (ARRAY['team'::character varying, 'individual'::character varying, 'opponent'::character varying]::text[])", name: "vod_reviews_review_type_check"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'in_progress'::character varying, 'completed'::character varying, 'archived'::character varying]::text[])", name: "vod_reviews_status_check"
    t.unique_constraint ["share_link"], name: "vod_reviews_share_link_key"
  end

  create_table "vod_timestamps", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "vod_review_id", null: false
    t.integer "timestamp_seconds", null: false
    t.string "title", limit: 100, null: false
    t.text "description"
    t.string "category", limit: 30
    t.string "target_type", limit: 20
    t.uuid "target_player_id"
    t.uuid "created_by"
    t.string "importance", limit: 10, default: "normal"
    t.jsonb "metadata", default: {}
    t.timestamptz "created_at", default: -> { "now()" }
    t.index ["category"], name: "idx_vod_timestamps_category"
    t.index ["vod_review_id"], name: "idx_vod_timestamps_review"
    t.check_constraint "category::text = ANY (ARRAY['mistake'::character varying, 'good_play'::character varying, 'learning_point'::character varying, 'strategy'::character varying, 'communication'::character varying, 'other'::character varying]::text[])", name: "vod_timestamps_category_check"
    t.check_constraint "importance::text = ANY (ARRAY['low'::character varying, 'normal'::character varying, 'high'::character varying, 'critical'::character varying]::text[])", name: "vod_timestamps_importance_check"
    t.check_constraint "target_type::text = ANY (ARRAY['team'::character varying, 'player'::character varying, 'opponent'::character varying]::text[])", name: "vod_timestamps_target_type_check"
  end

  add_foreign_key "audit_logs", "organizations", name: "audit_logs_organization_id_fkey", on_delete: :cascade
  add_foreign_key "audit_logs", "users", name: "audit_logs_user_id_fkey", on_delete: :nullify
  add_foreign_key "champion_pools", "players", name: "champion_pools_player_id_fkey", on_delete: :cascade
  add_foreign_key "matches", "organizations", name: "matches_organization_id_fkey", on_delete: :cascade
  add_foreign_key "notifications", "users", name: "notifications_user_id_fkey", on_delete: :cascade
  add_foreign_key "player_match_stats", "matches", name: "player_match_stats_match_id_fkey", on_delete: :cascade
  add_foreign_key "player_match_stats", "players", name: "player_match_stats_player_id_fkey", on_delete: :cascade
  add_foreign_key "players", "organizations", name: "players_organization_id_fkey", on_delete: :cascade
  add_foreign_key "schedules", "matches", name: "schedules_match_id_fkey"
  add_foreign_key "schedules", "organizations", name: "schedules_organization_id_fkey", on_delete: :cascade
  add_foreign_key "schedules", "users", column: "created_by", name: "schedules_created_by_fkey"
  add_foreign_key "scouting_targets", "organizations", name: "scouting_targets_organization_id_fkey", on_delete: :cascade
  add_foreign_key "scouting_targets", "users", column: "added_by", name: "scouting_targets_added_by_fkey"
  add_foreign_key "scouting_targets", "users", column: "assigned_to", name: "scouting_targets_assigned_to_fkey"
  add_foreign_key "team_goals", "organizations", name: "team_goals_organization_id_fkey", on_delete: :cascade
  add_foreign_key "team_goals", "players", name: "team_goals_player_id_fkey", on_delete: :cascade
  add_foreign_key "team_goals", "users", column: "assigned_to", name: "team_goals_assigned_to_fkey"
  add_foreign_key "team_goals", "users", column: "created_by", name: "team_goals_created_by_fkey"
  add_foreign_key "users", "auth.users", column: "id", name: "users_id_fkey", on_delete: :cascade
  add_foreign_key "users", "organizations", name: "users_organization_id_fkey", on_delete: :cascade
  add_foreign_key "vod_reviews", "matches", name: "vod_reviews_match_id_fkey", on_delete: :cascade
  add_foreign_key "vod_reviews", "organizations", name: "vod_reviews_organization_id_fkey", on_delete: :cascade
  add_foreign_key "vod_reviews", "users", column: "reviewer_id", name: "vod_reviews_reviewer_id_fkey"
  add_foreign_key "vod_timestamps", "players", column: "target_player_id", name: "vod_timestamps_target_player_id_fkey"
  add_foreign_key "vod_timestamps", "users", column: "created_by", name: "vod_timestamps_created_by_fkey"
  add_foreign_key "vod_timestamps", "vod_reviews", name: "vod_timestamps_vod_review_id_fkey", on_delete: :cascade
end
