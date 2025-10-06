class PlayerSerializer < Blueprinter::Base
  identifier :id

  fields :summoner_name, :real_name, :role, :status,
         :jersey_number, :birth_date, :country,
         :contract_start_date, :contract_end_date,
         :solo_queue_tier, :solo_queue_rank, :solo_queue_lp,
         :solo_queue_wins, :solo_queue_losses,
         :flex_queue_tier, :flex_queue_rank, :flex_queue_lp,
         :peak_tier, :peak_rank, :peak_season,
         :riot_puuid, :riot_summoner_id,
         :twitter_handle, :twitch_channel, :instagram_handle,
         :notes, :last_sync_at, :created_at, :updated_at

  field :age do |player|
    player.age
  end

  field :win_rate do |player|
    player.win_rate
  end

  field :current_rank do |player|
    player.current_rank_display
  end

  field :peak_rank do |player|
    player.peak_rank_display
  end

  field :contract_status do |player|
    player.contract_status
  end

  field :main_champions do |player|
    player.main_champions
  end

  field :social_links do |player|
    player.social_links
  end

  field :needs_sync do |player|
    player.needs_sync?
  end

  association :organization, blueprint: OrganizationSerializer
end
