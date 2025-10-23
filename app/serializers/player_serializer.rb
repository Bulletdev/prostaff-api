# frozen_string_literal: true

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
         :notes, :sync_status, :last_sync_at, :created_at, :updated_at

  field :age do |obj|
    obj.age
  end

  field :avatar_url do |player|
    if player.profile_icon_id.present?
      # Use latest patch version from Data Dragon
      "https://ddragon.leagueoflegends.com/cdn/14.1.1/img/profileicon/#{player.profile_icon_id}.png"
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
