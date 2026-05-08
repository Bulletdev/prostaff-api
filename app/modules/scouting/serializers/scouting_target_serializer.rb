# frozen_string_literal: true

# Serializer for ScoutingTarget model
# Renders global scouting prospect data with optional org-specific watchlist data
class ScoutingTargetSerializer < Blueprinter::Base
  identifier :id

  # Global fields (always present)
  fields :summoner_name, :role, :region, :status, :age
  fields :riot_puuid
  fields :current_tier, :current_rank, :current_lp
  fields :champion_pool, :playstyle, :strengths, :weaknesses
  fields :recent_performance, :performance_trend
  fields :email, :phone, :discord_username, :twitter_handle
  fields :notes # Player-specific notes (public)
  fields :metadata

  field :created_at do |target|
    target.created_at&.iso8601
  end

  field :updated_at do |target|
    target.updated_at&.iso8601
  end
  fields :real_name, :avatar_url, :profile_icon_id
  fields :peak_tier, :peak_rank, :last_api_sync_at
  fields :season_history

  # Computed fields
  field :status_text do |target|
    target.status&.titleize || 'Free Agent'
  end

  field :current_rank_display do |target|
    target.current_rank_display
  end

  # Avatar URL with fallback
  field :avatar_url do |target|
    target.avatar_url || target.metadata&.dig('avatar_url') || begin
      icon_id = target.profile_icon_id || target.metadata&.dig('profile_icon_id')
      if icon_id
        cdn = RiotCdnService.new
        "https://ddragon.leagueoflegends.com/cdn/#{cdn.cached_latest_version}/img/profileicon/#{icon_id}.png"
      end
    end
  end

  # Watchlist-specific fields (from context)
  # These are populated by the controller when rendering with watchlist context
  field :priority do |_target, options|
    options[:watchlist]&.priority
  end

  field :priority_text do |_target, options|
    options[:watchlist]&.priority&.titleize || 'Not Set'
  end

  field :watchlist_status do |_target, options|
    options[:watchlist]&.status || 'not_watching'
  end

  field :watchlist_notes do |_target, options|
    options[:watchlist]&.notes
  end

  field :last_reviewed do |_target, options|
    options[:watchlist]&.last_reviewed
  end

  field :added_by_id do |_target, options|
    options[:watchlist]&.added_by_id
  end

  field :assigned_to_id do |_target, options|
    options[:watchlist]&.assigned_to_id
  end

  field :in_watchlist do |_target, options|
    options[:watchlist].present?
  end

  # Associations (only if watchlist exists)
  field :added_by do |_target, options|
    JSON.parse(UserSerializer.render(options[:watchlist].added_by)) if options[:watchlist]&.added_by
  end

  field :assigned_to do |_target, options|
    JSON.parse(UserSerializer.render(options[:watchlist].assigned_to)) if options[:watchlist]&.assigned_to
  end

  # Helper method to render with watchlist context
  # @param targets [Array<ScoutingTarget>] Targets to serialize
  # @param organization [Organization] Current organization for watchlist context
  # @return [String] JSON string
  def self.render_with_watchlist(targets, organization)
    targets_with_watchlists = targets.map do |target|
      watchlist = target.scouting_watchlists.find { |w| w.organization_id == organization.id }
      { target: target, watchlist: watchlist }
    end

    targets_with_watchlists.map do |data|
      JSON.parse(render(data[:target], watchlist: data[:watchlist]))
    end
  end
end
