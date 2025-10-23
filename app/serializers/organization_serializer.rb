# frozen_string_literal: true

class OrganizationSerializer < Blueprinter::Base
  identifier :id

  fields :name, :slug, :region, :tier, :subscription_plan, :subscription_status,
         :logo_url, :settings, :created_at, :updated_at

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

  field :statistics do |org|
    {
      total_players: org.players.count,
      active_players: org.players.active.count,
      total_matches: org.matches.count,
      recent_matches: org.matches.recent(30).count,
      total_users: org.users.count
    }
  end

  # Tier features and capabilities
  field :features do |org|
    {
      can_access_scrims: org.can_access_scrims?,
      can_access_competitive_data: org.can_access_competitive_data?,
      can_access_predictive_analytics: org.can_access_predictive_analytics?,
      available_features: org.available_features,
      available_data_sources: org.available_data_sources,
      available_analytics: org.available_analytics
    }
  end

  field :limits do |org|
    {
      max_players: org.tier_limits[:max_players],
      max_matches_per_month: org.tier_limits[:max_matches_per_month],
      current_players: org.tier_limits[:current_players],
      current_monthly_matches: org.tier_limits[:current_monthly_matches],
      players_remaining: org.tier_limits[:players_remaining],
      matches_remaining: org.tier_limits[:matches_remaining]
    }
  end
end
