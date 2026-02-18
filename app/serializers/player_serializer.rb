# frozen_string_literal: true

# Serializer for Player model
# Renders player data with rank, stats, and profile information
class PlayerSerializer < Blueprinter::Base
  identifier :id

  fields :summoner_name, :real_name, :role, :status,
         :jersey_number, :birth_date, :country,
         :contract_start_date, :contract_end_date,
         :solo_queue_tier, :solo_queue_rank, :solo_queue_lp,
         :solo_queue_wins, :solo_queue_losses,
         :flex_queue_tier, :flex_queue_rank, :flex_queue_lp,
         :peak_tier, :peak_rank, :peak_season,
         :riot_puuid, :riot_summoner_id, :profile_icon_id,
         :twitter_handle, :twitch_channel, :instagram_handle,
         :kick_url, :professional_name,
         :notes, :sync_status, :last_sync_at, :created_at, :updated_at,
         :player_access_enabled, :player_email, :deleted_at, :removed_reason

  field :age do |obj|
    obj.age
  end

  field :avatar_url do |player|
    # Use custom avatar_url if present and not blank, otherwise fallback to Riot profile icon
    if player.avatar_url.present? && player.avatar_url.strip.present?
      player.avatar_url
    elsif player.profile_icon_id.present?
      RiotCdnService.new.profile_icon_url(player.profile_icon_id)
    end
  end

  field :win_rate do |obj|
    obj.win_rate
  end

  field :current_rank do |obj|
    obj.current_rank_display
  end

  field :peak_rank do |obj|
    obj.peak_rank_display
  end

  field :contract_status do |obj|
    obj.contract_status
  end

  field :main_champions do |obj|
    obj.main_champions
  end

  field :social_links do |obj|
    obj.social_links
  end

  field :needs_sync do |obj|
    obj.needs_sync?
  end

  association :organization, blueprint: OrganizationSerializer
end
