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

ActiveRecord::Schema[7.2].define(version: 20_251_017_194_806) do
  create_schema 'auth'
  create_schema 'extensions'
  create_schema 'graphql'
  create_schema 'graphql_public'
  create_schema 'pgbouncer'
  create_schema 'realtime'
  create_schema 'storage'
  create_schema 'supabase_migrations'
  create_schema 'vault'

  # These are extensions that must be enabled in order to support this database
  enable_extension 'pg_graphql'
  enable_extension 'pg_stat_statements'
  enable_extension 'pgcrypto'
  enable_extension 'plpgsql'
  enable_extension 'supabase_vault'
  enable_extension 'uuid-ossp'

  create_table 'audit_logs', id: :uuid, default: -> { 'gen_random_uuid()' }, force: :cascade do |t|
    t.uuid 'organization_id', null: false
    t.uuid 'user_id'
    t.string 'action', null: false
    t.string 'entity_type', null: false
    t.uuid 'entity_id'
    t.jsonb 'old_values'
    t.jsonb 'new_values'
    t.inet 'ip_address'
    t.text 'user_agent'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['created_at'], name: 'index_audit_logs_on_created_at'
    t.index ['entity_id'], name: 'index_audit_logs_on_entity_id'
    t.index %w[entity_type entity_id], name: 'index_audit_logs_on_entity_type_and_entity_id'
    t.index ['entity_type'], name: 'index_audit_logs_on_entity_type'
    t.index %w[organization_id created_at], name: 'index_audit_logs_on_org_and_created'
    t.index ['organization_id'], name: 'index_audit_logs_on_organization_id'
    t.index ['user_id'], name: 'index_audit_logs_on_user_id'
  end

  create_table 'champion_pools', id: :uuid, default: -> { 'gen_random_uuid()' }, force: :cascade do |t|
    t.uuid 'player_id', null: false
    t.string 'champion', null: false
    t.integer 'games_played', default: 0
    t.integer 'games_won', default: 0
    t.integer 'mastery_level', default: 1
    t.decimal 'average_kda', precision: 5, scale: 2
    t.decimal 'average_cs_per_min', precision: 5, scale: 2
    t.decimal 'average_damage_share', precision: 5, scale: 2
    t.boolean 'is_comfort_pick', default: false
    t.boolean 'is_pocket_pick', default: false
    t.boolean 'is_learning', default: false
    t.integer 'priority', default: 5
    t.datetime 'last_played', precision: nil
    t.text 'notes'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['champion'], name: 'index_champion_pools_on_champion'
    t.index %w[player_id champion], name: 'index_champion_pools_on_player_id_and_champion', unique: true
    t.index ['player_id'], name: 'index_champion_pools_on_player_id'
    t.index ['priority'], name: 'index_champion_pools_on_priority'
  end

  create_table 'competitive_matches', id: :uuid, default: -> { 'gen_random_uuid()' }, force: :cascade do |t|
    t.uuid 'organization_id', null: false
    t.string 'tournament_name', null: false
    t.string 'tournament_stage'
    t.string 'tournament_region'
    t.string 'external_match_id'
    t.datetime 'match_date'
    t.string 'match_format'
    t.integer 'game_number'
    t.string 'our_team_name'
    t.string 'opponent_team_name'
    t.uuid 'opponent_team_id'
    t.boolean 'victory'
    t.string 'series_score'
    t.jsonb 'our_bans', default: []
    t.jsonb 'opponent_bans', default: []
    t.jsonb 'our_picks', default: []
    t.jsonb 'opponent_picks', default: []
    t.string 'side'
    t.uuid 'match_id'
    t.jsonb 'game_stats', default: {}
    t.string 'patch_version'
    t.text 'meta_champions', default: [], array: true
    t.string 'vod_url'
    t.string 'external_stats_url'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['external_match_id'], name: 'index_competitive_matches_on_external_match_id', unique: true
    t.index ['match_date'], name: 'index_competitive_matches_on_match_date'
    t.index ['opponent_team_id'], name: 'index_competitive_matches_on_opponent_team_id'
    t.index %w[organization_id tournament_name], name: 'idx_comp_matches_org_tournament'
    t.index ['organization_id'], name: 'index_competitive_matches_on_organization_id'
    t.index ['patch_version'], name: 'index_competitive_matches_on_patch_version'
    t.index %w[tournament_region match_date], name: 'idx_comp_matches_region_date'
  end

  create_table 'matches', id: :uuid, default: -> { 'gen_random_uuid()' }, force: :cascade do |t|
    t.uuid 'organization_id', null: false
    t.string 'match_type', null: false
    t.string 'riot_match_id'
    t.string 'game_version'
    t.datetime 'game_start', precision: nil
    t.datetime 'game_end', precision: nil
    t.integer 'game_duration'
    t.string 'our_side'
    t.string 'opponent_name'
    t.string 'opponent_tag'
    t.boolean 'victory'
    t.integer 'our_score'
    t.integer 'opponent_score'
    t.integer 'our_towers'
    t.integer 'opponent_towers'
    t.integer 'our_dragons'
    t.integer 'opponent_dragons'
    t.integer 'our_barons'
    t.integer 'opponent_barons'
    t.integer 'our_inhibitors'
    t.integer 'opponent_inhibitors'
    t.text 'our_bans', default: [], array: true
    t.text 'opponent_bans', default: [], array: true
    t.string 'vod_url'
    t.string 'replay_file_url'
    t.text 'tags', default: [], array: true
    t.text 'notes'
    t.jsonb 'metadata', default: {}
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['game_start'], name: 'index_matches_on_game_start'
    t.index ['match_type'], name: 'index_matches_on_match_type'
    t.index %w[organization_id game_start], name: 'idx_matches_org_game_start'
    t.index %w[organization_id game_start], name: 'index_matches_on_org_and_game_start'
    t.index %w[organization_id victory], name: 'idx_matches_org_victory'
    t.index %w[organization_id victory], name: 'index_matches_on_org_and_victory'
    t.index ['organization_id'], name: 'index_matches_on_organization_id'
    t.index ['riot_match_id'], name: 'index_matches_on_riot_match_id', unique: true
    t.index ['victory'], name: 'index_matches_on_victory'
  end

  create_table 'opponent_teams', id: :uuid, default: -> { 'gen_random_uuid()' }, force: :cascade do |t|
    t.string 'name', null: false
    t.string 'tag'
    t.string 'region'
    t.string 'tier'
    t.string 'league'
    t.string 'logo_url'
    t.text 'known_players', default: [], array: true
    t.jsonb 'recent_performance', default: {}
    t.integer 'total_scrims', default: 0
    t.integer 'scrims_won', default: 0
    t.integer 'scrims_lost', default: 0
    t.text 'playstyle_notes'
    t.text 'strengths', default: [], array: true
    t.text 'weaknesses', default: [], array: true
    t.jsonb 'preferred_champions', default: {}
    t.string 'contact_email'
    t.string 'discord_server'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['league'], name: 'index_opponent_teams_on_league'
    t.index ['name'], name: 'index_opponent_teams_on_name'
    t.index ['region'], name: 'index_opponent_teams_on_region'
    t.index ['tier'], name: 'index_opponent_teams_on_tier'
  end

  create_table 'organizations', id: :uuid, default: -> { 'gen_random_uuid()' }, force: :cascade do |t|
    t.string 'name', null: false
    t.string 'slug', null: false
    t.string 'region', null: false
    t.string 'tier'
    t.string 'subscription_plan'
    t.string 'subscription_status'
    t.string 'logo_url'
    t.jsonb 'settings', default: {}
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['region'], name: 'index_organizations_on_region'
    t.index ['slug'], name: 'index_organizations_on_slug', unique: true
    t.index ['subscription_plan'], name: 'index_organizations_on_subscription_plan'
  end

  create_table 'password_reset_tokens', id: :uuid, default: -> { 'gen_random_uuid()' }, force: :cascade do |t|
    t.uuid 'user_id', null: false
    t.string 'token', null: false
    t.string 'ip_address'
    t.string 'user_agent'
    t.datetime 'expires_at', null: false
    t.datetime 'used_at'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['expires_at'], name: 'index_password_reset_tokens_on_expires_at'
    t.index ['token'], name: 'index_password_reset_tokens_on_token', unique: true
    t.index %w[user_id used_at], name: 'index_password_reset_tokens_on_user_id_and_used_at'
    t.index ['user_id'], name: 'index_password_reset_tokens_on_user_id'
  end

  create_table 'player_match_stats', id: :uuid, default: -> { 'gen_random_uuid()' }, force: :cascade do |t|
    t.uuid 'match_id', null: false
    t.uuid 'player_id', null: false
    t.string 'champion', null: false
    t.string 'role'
    t.string 'lane'
    t.integer 'kills', default: 0
    t.integer 'deaths', default: 0
    t.integer 'assists', default: 0
    t.integer 'double_kills', default: 0
    t.integer 'triple_kills', default: 0
    t.integer 'quadra_kills', default: 0
    t.integer 'penta_kills', default: 0
    t.integer 'largest_killing_spree'
    t.integer 'largest_multi_kill'
    t.integer 'cs', default: 0
    t.decimal 'cs_per_min', precision: 5, scale: 2
    t.integer 'gold_earned'
    t.decimal 'gold_per_min', precision: 8, scale: 2
    t.decimal 'gold_share', precision: 5, scale: 2
    t.integer 'damage_dealt_champions'
    t.integer 'damage_dealt_total'
    t.integer 'damage_dealt_objectives'
    t.integer 'damage_taken'
    t.integer 'damage_mitigated'
    t.decimal 'damage_share', precision: 5, scale: 2
    t.integer 'vision_score'
    t.integer 'wards_placed'
    t.integer 'wards_destroyed'
    t.integer 'control_wards_purchased'
    t.decimal 'kill_participation', precision: 5, scale: 2
    t.boolean 'first_blood', default: false
    t.boolean 'first_tower', default: false
    t.integer 'items', default: [], array: true
    t.integer 'item_build_order', default: [], array: true
    t.integer 'trinket'
    t.string 'summoner_spell_1'
    t.string 'summoner_spell_2'
    t.string 'primary_rune_tree'
    t.string 'secondary_rune_tree'
    t.integer 'runes', default: [], array: true
    t.integer 'healing_done'
    t.decimal 'performance_score', precision: 5, scale: 2
    t.jsonb 'metadata', default: {}
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['champion'], name: 'index_player_match_stats_on_champion'
    t.index ['match_id'], name: 'idx_player_stats_match'
    t.index ['match_id'], name: 'index_player_match_stats_on_match'
    t.index ['match_id'], name: 'index_player_match_stats_on_match_id'
    t.index %w[player_id match_id], name: 'index_player_match_stats_on_player_id_and_match_id', unique: true
    t.index ['player_id'], name: 'index_player_match_stats_on_player_id'
  end

  create_table 'players', id: :uuid, default: -> { 'gen_random_uuid()' }, force: :cascade do |t|
    t.uuid 'organization_id', null: false
    t.string 'summoner_name', null: false
    t.string 'real_name'
    t.string 'role', null: false
    t.string 'country'
    t.date 'birth_date'
    t.string 'status', default: 'active'
    t.string 'riot_puuid'
    t.string 'riot_summoner_id'
    t.string 'riot_account_id'
    t.integer 'profile_icon_id'
    t.integer 'summoner_level'
    t.string 'solo_queue_tier'
    t.string 'solo_queue_rank'
    t.integer 'solo_queue_lp'
    t.integer 'solo_queue_wins'
    t.integer 'solo_queue_losses'
    t.string 'flex_queue_tier'
    t.string 'flex_queue_rank'
    t.integer 'flex_queue_lp'
    t.string 'peak_tier'
    t.string 'peak_rank'
    t.string 'peak_season'
    t.date 'contract_start_date'
    t.date 'contract_end_date'
    t.decimal 'salary', precision: 10, scale: 2
    t.integer 'jersey_number'
    t.text 'champion_pool', default: [], array: true
    t.string 'preferred_role_secondary'
    t.text 'playstyle_tags', default: [], array: true
    t.string 'twitter_handle'
    t.string 'twitch_channel'
    t.string 'instagram_handle'
    t.text 'notes'
    t.jsonb 'metadata', default: {}
    t.datetime 'last_sync_at', precision: nil
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.string 'sync_status'
    t.string 'region'
    t.index %w[organization_id role], name: 'index_players_on_org_and_role'
    t.index %w[organization_id status], name: 'idx_players_org_status'
    t.index %w[organization_id status], name: 'index_players_on_org_and_status'
    t.index ['organization_id'], name: 'index_players_on_organization_id'
    t.index ['riot_puuid'], name: 'index_players_on_riot_puuid', unique: true
    t.index ['role'], name: 'index_players_on_role'
    t.index ['status'], name: 'index_players_on_status'
    t.index ['summoner_name'], name: 'index_players_on_summoner_name'
  end

  create_table 'schedules', id: :uuid, default: -> { 'gen_random_uuid()' }, force: :cascade do |t|
    t.uuid 'organization_id', null: false
    t.string 'title', null: false
    t.text 'description'
    t.string 'event_type', null: false
    t.datetime 'start_time', precision: nil, null: false
    t.datetime 'end_time', precision: nil, null: false
    t.string 'timezone'
    t.boolean 'all_day', default: false
    t.uuid 'match_id'
    t.string 'opponent_name'
    t.string 'location'
    t.string 'meeting_url'
    t.uuid 'required_players', default: [], array: true
    t.uuid 'optional_players', default: [], array: true
    t.string 'status', default: 'scheduled'
    t.text 'tags', default: [], array: true
    t.string 'color'
    t.boolean 'is_recurring', default: false
    t.string 'recurrence_rule'
    t.date 'recurrence_end_date'
    t.integer 'reminder_minutes', default: [], array: true
    t.uuid 'created_by_id'
    t.jsonb 'metadata', default: {}
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['created_by_id'], name: 'index_schedules_on_created_by_id'
    t.index ['event_type'], name: 'index_schedules_on_event_type'
    t.index ['match_id'], name: 'index_schedules_on_match_id'
    t.index %w[organization_id start_time event_type], name: 'index_schedules_on_org_time_type'
    t.index %w[organization_id start_time], name: 'idx_schedules_org_time'
    t.index ['organization_id'], name: 'index_schedules_on_organization_id'
    t.index ['start_time'], name: 'index_schedules_on_start_time'
    t.index ['status'], name: 'index_schedules_on_status'
  end

  create_table 'scouting_targets', id: :uuid, default: -> { 'gen_random_uuid()' }, force: :cascade do |t|
    t.uuid 'organization_id', null: false
    t.string 'summoner_name', null: false
    t.string 'region', null: false
    t.string 'riot_puuid'
    t.string 'role', null: false
    t.string 'current_tier'
    t.string 'current_rank'
    t.integer 'current_lp'
    t.text 'champion_pool', default: [], array: true
    t.string 'playstyle'
    t.text 'strengths', default: [], array: true
    t.text 'weaknesses', default: [], array: true
    t.jsonb 'recent_performance', default: {}
    t.string 'performance_trend'
    t.string 'email'
    t.string 'phone'
    t.string 'discord_username'
    t.string 'twitter_handle'
    t.string 'status', default: 'watching'
    t.string 'priority', default: 'medium'
    t.uuid 'added_by_id'
    t.uuid 'assigned_to_id'
    t.datetime 'last_reviewed', precision: nil
    t.text 'notes'
    t.jsonb 'metadata', default: {}
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.integer 'age'
    t.index ['added_by_id'], name: 'index_scouting_targets_on_added_by_id'
    t.index ['assigned_to_id'], name: 'index_scouting_targets_on_assigned_to_id'
    t.index ['organization_id'], name: 'index_scouting_targets_on_organization_id'
    t.index ['priority'], name: 'index_scouting_targets_on_priority'
    t.index ['riot_puuid'], name: 'index_scouting_targets_on_riot_puuid'
    t.index ['role'], name: 'index_scouting_targets_on_role'
    t.index ['status'], name: 'index_scouting_targets_on_status'
  end

  create_table 'scrims', id: :uuid, default: -> { 'gen_random_uuid()' }, force: :cascade do |t|
    t.uuid 'organization_id', null: false
    t.uuid 'match_id'
    t.uuid 'opponent_team_id'
    t.datetime 'scheduled_at'
    t.string 'scrim_type'
    t.string 'focus_area'
    t.text 'pre_game_notes'
    t.text 'post_game_notes'
    t.boolean 'is_confidential', default: true
    t.string 'visibility'
    t.integer 'games_planned'
    t.integer 'games_completed'
    t.jsonb 'game_results', default: []
    t.jsonb 'objectives', default: {}
    t.jsonb 'outcomes', default: {}
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['match_id'], name: 'index_scrims_on_match_id'
    t.index ['opponent_team_id'], name: 'index_scrims_on_opponent_team_id'
    t.index %w[organization_id scheduled_at], name: 'idx_scrims_org_scheduled'
    t.index ['organization_id'], name: 'index_scrims_on_organization_id'
    t.index ['scheduled_at'], name: 'index_scrims_on_scheduled_at'
    t.index ['scrim_type'], name: 'index_scrims_on_scrim_type'
  end

  create_table 'team_goals', id: :uuid, default: -> { 'gen_random_uuid()' }, force: :cascade do |t|
    t.uuid 'organization_id', null: false
    t.uuid 'player_id'
    t.string 'title', null: false
    t.text 'description'
    t.string 'category'
    t.string 'metric_type'
    t.decimal 'target_value', precision: 10, scale: 2
    t.decimal 'current_value', precision: 10, scale: 2
    t.date 'start_date', null: false
    t.date 'end_date', null: false
    t.string 'status', default: 'active'
    t.integer 'progress', default: 0
    t.uuid 'assigned_to_id'
    t.uuid 'created_by_id'
    t.jsonb 'metadata', default: {}
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['assigned_to_id'], name: 'index_team_goals_on_assigned_to_id'
    t.index ['category'], name: 'index_team_goals_on_category'
    t.index ['created_by_id'], name: 'index_team_goals_on_created_by_id'
    t.index %w[organization_id status], name: 'idx_team_goals_org_status'
    t.index %w[organization_id status], name: 'index_team_goals_on_org_and_status'
    t.index ['organization_id'], name: 'index_team_goals_on_organization_id'
    t.index ['player_id'], name: 'index_team_goals_on_player_id'
    t.index ['status'], name: 'index_team_goals_on_status'
  end

  create_table 'token_blacklists', id: :uuid, default: -> { 'gen_random_uuid()' }, force: :cascade do |t|
    t.string 'jti', null: false
    t.datetime 'expires_at', null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['expires_at'], name: 'index_token_blacklists_on_expires_at'
    t.index ['jti'], name: 'index_token_blacklists_on_jti', unique: true
  end

  create_table 'users', id: :uuid, default: -> { 'gen_random_uuid()' }, force: :cascade do |t|
    t.uuid 'organization_id', null: false
    t.string 'email', null: false
    t.string 'password_digest', null: false
    t.string 'full_name'
    t.string 'role', null: false
    t.string 'avatar_url'
    t.string 'timezone'
    t.string 'language'
    t.boolean 'notifications_enabled', default: true
    t.jsonb 'notification_preferences', default: {}
    t.datetime 'last_login_at', precision: nil
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.string 'supabase_uid'
    t.index ['email'], name: 'index_users_on_email', unique: true
    t.index ['organization_id'], name: 'index_users_on_organization_id'
    t.index ['role'], name: 'index_users_on_role'
    t.index ['supabase_uid'], name: 'index_users_on_supabase_uid'
  end

  create_table 'vod_reviews', id: :uuid, default: -> { 'gen_random_uuid()' }, force: :cascade do |t|
    t.uuid 'organization_id', null: false
    t.uuid 'match_id'
    t.string 'title', null: false
    t.text 'description'
    t.string 'review_type'
    t.datetime 'review_date', precision: nil
    t.string 'video_url', null: false
    t.string 'thumbnail_url'
    t.integer 'duration'
    t.boolean 'is_public', default: false
    t.string 'share_link'
    t.uuid 'shared_with_players', default: [], array: true
    t.uuid 'reviewer_id'
    t.string 'status', default: 'draft'
    t.text 'tags', default: [], array: true
    t.jsonb 'metadata', default: {}
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['match_id'], name: 'index_vod_reviews_on_match_id'
    t.index ['organization_id'], name: 'index_vod_reviews_on_organization_id'
    t.index ['reviewer_id'], name: 'index_vod_reviews_on_reviewer_id'
    t.index ['share_link'], name: 'index_vod_reviews_on_share_link', unique: true
    t.index ['status'], name: 'index_vod_reviews_on_status'
  end

  create_table 'vod_timestamps', id: :uuid, default: -> { 'gen_random_uuid()' }, force: :cascade do |t|
    t.uuid 'vod_review_id', null: false
    t.integer 'timestamp_seconds', null: false
    t.string 'title', null: false
    t.text 'description'
    t.string 'category'
    t.string 'importance', default: 'normal'
    t.string 'target_type'
    t.uuid 'target_player_id'
    t.uuid 'created_by_id'
    t.jsonb 'metadata', default: {}
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['category'], name: 'index_vod_timestamps_on_category'
    t.index ['created_by_id'], name: 'index_vod_timestamps_on_created_by_id'
    t.index ['importance'], name: 'index_vod_timestamps_on_importance'
    t.index ['target_player_id'], name: 'index_vod_timestamps_on_target_player_id'
    t.index ['timestamp_seconds'], name: 'index_vod_timestamps_on_timestamp_seconds'
    t.index ['vod_review_id'], name: 'index_vod_timestamps_on_vod_review_id'
  end

  add_foreign_key 'audit_logs', 'organizations'
  add_foreign_key 'audit_logs', 'users'
  add_foreign_key 'champion_pools', 'players'
  add_foreign_key 'competitive_matches', 'matches'
  add_foreign_key 'competitive_matches', 'opponent_teams'
  add_foreign_key 'competitive_matches', 'organizations'
  add_foreign_key 'matches', 'organizations'
  add_foreign_key 'password_reset_tokens', 'users'
  add_foreign_key 'player_match_stats', 'matches'
  add_foreign_key 'player_match_stats', 'players'
  add_foreign_key 'players', 'organizations'
  add_foreign_key 'schedules', 'matches'
  add_foreign_key 'schedules', 'organizations'
  add_foreign_key 'schedules', 'users', column: 'created_by_id'
  add_foreign_key 'scouting_targets', 'organizations'
  add_foreign_key 'scouting_targets', 'users', column: 'added_by_id'
  add_foreign_key 'scouting_targets', 'users', column: 'assigned_to_id'
  add_foreign_key 'scrims', 'matches'
  add_foreign_key 'scrims', 'opponent_teams'
  add_foreign_key 'scrims', 'organizations'
  add_foreign_key 'team_goals', 'organizations'
  add_foreign_key 'team_goals', 'players'
  add_foreign_key 'team_goals', 'users', column: 'assigned_to_id'
  add_foreign_key 'team_goals', 'users', column: 'created_by_id'
  add_foreign_key 'users', 'organizations'
  add_foreign_key 'vod_reviews', 'matches'
  add_foreign_key 'vod_reviews', 'organizations'
  add_foreign_key 'vod_reviews', 'users', column: 'reviewer_id'
  add_foreign_key 'vod_timestamps', 'players', column: 'target_player_id'
  add_foreign_key 'vod_timestamps', 'users', column: 'created_by_id'
  add_foreign_key 'vod_timestamps', 'vod_reviews'
end
