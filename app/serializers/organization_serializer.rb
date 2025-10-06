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
end