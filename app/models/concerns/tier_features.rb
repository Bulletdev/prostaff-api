# frozen_string_literal: true

module TierFeatures
  extend ActiveSupport::Concern

  TIER_FEATURES = {
    tier_3_amateur: {
      subscription_plans: %w[free amateur],
      max_players: 10,
      max_matches_per_month: 50,
      data_retention_months: 3,
      data_sources: %w[soloq],
      analytics: %w[basic],
      features: %w[vod_reviews champion_pools schedules],
      api_access: false
    },
    tier_2_semi_pro: {
      subscription_plans: %w[semi_pro],
      max_players: 25,
      max_matches_per_month: 200,
      data_retention_months: 12,
      data_sources: %w[soloq scrims regional_tournaments],
      analytics: %w[basic advanced scrim_analysis],
      features: %w[
        vod_reviews champion_pools schedules
        scrims draft_analysis team_composition opponent_database
      ],
      api_access: false
    },
    tier_1_professional: {
      subscription_plans: %w[professional enterprise],
      max_players: 50,
      max_matches_per_month: nil, # unlimited
      data_retention_months: nil, # unlimited
      data_sources: %w[soloq scrims official_competitive international],
      analytics: %w[basic advanced predictive meta_analysis],
      features: %w[
        vod_reviews champion_pools schedules
        scrims draft_analysis team_composition opponent_database
        competitive_data predictive_analytics meta_analysis
        patch_impact player_form_tracking
      ],
      api_access: true # only for enterprise plan
    }
  }.freeze

  # Check if organization can access a specific feature
  def can_access?(feature_name)
    tier_config = TIER_FEATURES[tier_symbol] || TIER_FEATURES[:tier_3_amateur]
    tier_config[:features].include?(feature_name.to_s)
  end

  # Scrim access
  def can_access_scrims?
    tier.in?(%w[tier_2_semi_pro tier_1_professional])
  end

  def can_create_scrim?
    return false unless can_access_scrims?

    monthly_scrims_count = scrims.where('created_at > ?', 1.month.ago).count

    case tier
    when 'tier_2_semi_pro'
      monthly_scrims_count < 50
    when 'tier_1_professional'
      true # unlimited
    else
      false
    end
  end

  # Competitive data access
  def can_access_competitive_data?
    tier == 'tier_1_professional'
  end

  # Predictive analytics access
  def can_access_predictive_analytics?
    tier == 'tier_1_professional'
  end

  # API access (Enterprise only)
  def can_access_api?
    tier == 'tier_1_professional' && subscription_plan == 'enterprise'
  end

  # Match limits
  def match_limit_reached?
    tier_config = TIER_FEATURES[tier_symbol] || TIER_FEATURES[:tier_3_amateur]
    max_matches = tier_config[:max_matches_per_month]

    return false if max_matches.nil? # unlimited

    monthly_matches = matches.where('created_at > ?', 1.month.ago).count
    monthly_matches >= max_matches
  end

  def matches_remaining_this_month
    tier_config = TIER_FEATURES[tier_symbol] || TIER_FEATURES[:tier_3_amateur]
    max_matches = tier_config[:max_matches_per_month]

    return nil if max_matches.nil? # unlimited

    monthly_matches = matches.where('created_at > ?', 1.month.ago).count
    [max_matches - monthly_matches, 0].max
  end

  # Player limits
  def player_limit_reached?
    tier_config = TIER_FEATURES[tier_symbol] || TIER_FEATURES[:tier_3_amateur]
    players.count >= tier_config[:max_players]
  end

  def players_remaining
    tier_config = TIER_FEATURES[tier_symbol] || TIER_FEATURES[:tier_3_amateur]
    max_players = tier_config[:max_players]

    [max_players - players.count, 0].max
  end

  # Analytics level
  def analytics_level
    case tier
    when 'tier_3_amateur'
      :basic
    when 'tier_2_semi_pro'
      :advanced
    when 'tier_1_professional'
      :predictive
    else
      :basic
    end
  end

  # Data retention check
  def data_retention_cutoff
    tier_config = TIER_FEATURES[tier_symbol] || TIER_FEATURES[:tier_3_amateur]
    months = tier_config[:data_retention_months]

    return nil if months.nil? # unlimited

    months.months.ago
  end

  # Tier information
  def tier_display_name
    case tier
    when 'tier_3_amateur'
      'Amateur (Tier 3)'
    when 'tier_2_semi_pro'
      'Semi-Pro (Tier 2)'
    when 'tier_1_professional'
      'Professional (Tier 1)'
    else
      'Unknown'
    end
  end

  def tier_limits
    tier_config = TIER_FEATURES[tier_symbol] || TIER_FEATURES[:tier_3_amateur]

    {
      max_players: tier_config[:max_players],
      max_matches_per_month: tier_config[:max_matches_per_month],
      data_retention_months: tier_config[:data_retention_months],
      current_players: players.count,
      current_monthly_matches: matches.where('created_at > ?', 1.month.ago).count,
      players_remaining: players_remaining,
      matches_remaining: matches_remaining_this_month
    }
  end

  def available_features
    tier_config = TIER_FEATURES[tier_symbol] || TIER_FEATURES[:tier_3_amateur]
    tier_config[:features]
  end

  def available_data_sources
    tier_config = TIER_FEATURES[tier_symbol] || TIER_FEATURES[:tier_3_amateur]
    tier_config[:data_sources]
  end

  def available_analytics
    tier_config = TIER_FEATURES[tier_symbol] || TIER_FEATURES[:tier_3_amateur]
    tier_config[:analytics]
  end

  # Upgrade suggestions
  def suggested_upgrade
    case tier
    when 'tier_3_amateur'
      {
        tier: 'tier_2_semi_pro',
        name: 'Semi-Pro',
        benefits: [
          '25 players (from 10)',
          '200 matches/month (from 50)',
          'Scrim tracking',
          'Draft analysis',
          'Advanced analytics'
        ]
      }
    when 'tier_2_semi_pro'
      {
        tier: 'tier_1_professional',
        name: 'Professional',
        benefits: [
          '50 players (from 25)',
          'Unlimited matches',
          'Official competitive data',
          'Predictive analytics',
          'Meta analysis'
        ]
      }
    end
  end

  # Usage warnings
  def approaching_player_limit?
    return false if player_limit_reached?

    tier_config = TIER_FEATURES[tier_symbol] || TIER_FEATURES[:tier_3_amateur]
    max_players = tier_config[:max_players]

    players.count >= (max_players * 0.8).floor # 80% threshold
  end

  def approaching_match_limit?
    tier_config = TIER_FEATURES[tier_symbol] || TIER_FEATURES[:tier_3_amateur]
    max_matches = tier_config[:max_matches_per_month]

    return false if max_matches.nil? # unlimited
    return false if match_limit_reached?

    monthly_matches = matches.where('created_at > ?', 1.month.ago).count
    monthly_matches >= (max_matches * 0.8).floor # 80% threshold
  end

  private

  def tier_symbol
    tier&.to_sym || :tier_3_amateur
  end
end
