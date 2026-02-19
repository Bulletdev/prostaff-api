# frozen_string_literal: true

# Serializer for Organization model
# Renders organization details for API responses
class OrganizationSerializer < Blueprinter::Base
  identifier :id

  fields :name, :slug, :region, :tier, :subscription_plan, :subscription_status,
         :logo_url, :settings, :created_at, :updated_at,
         :trial_expires_at, :trial_started_at

  field :region_display do |org|
    region_names = {
      'BR' => 'Brazil',
      'NA' => 'North America',
      'EUW' => 'Europe West',
      'EUNE' => 'Europe Nordic & East',
      'KR' => 'Korea',
      'LAN' => 'Latin America North',
      'LAS' => 'Latin America South',
      'OCE' => 'Oceania',
      'RU' => 'Russia',
      'TR' => 'Turkey',
      'JP' => 'Japan'
    }

    region_names[org.region] || org.region
  end

  field :tier_display do |org|
    if org.tier.blank?
      'Not set'
    else
      org.tier.humanize
    end
  end

  field :subscription_display do |org|
    if org.subscription_plan.blank?
      'Free'
    else
      plan = org.subscription_plan.humanize
      status = org.subscription_status&.humanize || 'Active'
      "#{plan} (#{status})"
    end
  end

  # Trial information
  field :trial_info do |org|
    {
      on_trial: org.on_trial?,
      trial_expired: org.trial_expired?,
      days_remaining: org.trial_days_remaining,
      has_active_access: org.has_active_access?
    }
  end

  field :statistics do |org|
    # Cache for 2 minutes to avoid re-running these COUNT queries on every
    # /auth/me call (the frontend fires this endpoint 3-4 times per page load).
    Rails.cache.fetch("org_statistics_v1_#{org.id}", expires_in: 2.minutes) do
      # Single query for both total and active player counts
      player_row = org.players
        .where(deleted_at: nil)
        .select(
          "COUNT(*) AS total_count",
          "COUNT(*) FILTER (WHERE status = 'active') AS active_count"
        )
        .take

      {
        total_players:  player_row&.total_count.to_i,
        active_players: player_row&.active_count.to_i,
        total_matches:  org.matches.count,
        recent_matches: org.cached_monthly_matches_count,
        total_users:    org.users.count
      }
    end
  rescue => e
    Rails.logger.error("OrganizationSerializer statistics error: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace&.first(5)&.join("\n"))
    {
      total_players: 0,
      active_players: 0,
      total_matches: 0,
      recent_matches: 0,
      total_users: 0
    }
  end

  # Tier features and capabilities
  field :features do |org|
    begin
      {
        can_access_scrims: org.can_access_scrims?,
        can_access_competitive_data: org.can_access_competitive_data?,
        can_access_predictive_analytics: org.can_access_predictive_analytics?,
        available_features: org.available_features,
        available_data_sources: org.available_data_sources,
        available_analytics: org.available_analytics
      }
    rescue => e
      Rails.logger.error("OrganizationSerializer features error: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace&.first(5)&.join("\n"))
      {
        can_access_scrims: false,
        can_access_competitive_data: false,
        can_access_predictive_analytics: false,
        available_features: [],
        available_data_sources: [],
        available_analytics: []
      }
    end
  end

  field :limits do |org|
    begin
      # Chamar tier_limits uma única vez e retornar apenas os campos necessários
      limits = org.tier_limits
      {
        max_players: limits[:max_players],
        max_matches_per_month: limits[:max_matches_per_month],
        current_players: limits[:current_players],
        current_monthly_matches: limits[:current_monthly_matches],
        players_remaining: limits[:players_remaining],
        matches_remaining: limits[:matches_remaining]
      }
    rescue => e
      Rails.logger.error("OrganizationSerializer limits error: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace&.first(5)&.join("\n"))
      {
        max_players: 0,
        max_matches_per_month: 0,
        current_players: 0,
        current_monthly_matches: 0,
        players_remaining: 0,
        matches_remaining: 0
      }
    end
  end
end
