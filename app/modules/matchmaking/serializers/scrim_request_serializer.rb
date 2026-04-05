class ScrimRequestSerializer < Blueprinter::Base
  identifier :id

  fields :status, :game, :message, :proposed_at, :expires_at,
         :games_planned, :draft_type,
         :requesting_scrim_id, :target_scrim_id,
         :created_at, :updated_at

  field :requesting_organization do |req|
    serialize_org(req.requesting_organization)
  end

  field :target_organization do |req|
    serialize_org(req.target_organization)
  end

  field :pending do |req|
    req.pending?
  end

  field :expired do |req|
    req.expired?
  end

  class << self
    TIER_SCORE = {
      'CHALLENGER'  => 9, 'GRANDMASTER' => 8, 'MASTER'    => 7,
      'DIAMOND'     => 6, 'EMERALD'     => 5, 'PLATINUM'  => 4,
      'GOLD'        => 3, 'SILVER'      => 2, 'BRONZE'    => 1
    }.freeze

    TIER_LABEL = {
      9 => 'Challenger', 8 => 'Grandmaster', 7 => 'Master',
      6 => 'Diamond',    5 => 'Emerald',     4 => 'Platinum',
      3 => 'Gold',       2 => 'Silver',      1 => 'Bronze', 0 => 'Iron'
    }.freeze

    def serialize_org(org)
      players = org.players.active.select(:summoner_name, :role, :solo_queue_tier)

      scores = players.map { |p| TIER_SCORE[p.solo_queue_tier.to_s.upcase] || 0 }
      avg_score = scores.empty? ? 0 : (scores.sum.to_f / scores.size).round
      avg_tier  = TIER_LABEL[avg_score] || 'Iron'

      {
        id:            org.id,
        name:          org.name,
        slug:          org.slug,
        region:        org.region,
        tier:          org.tier,
        public_tagline: org.public_tagline,
        discord_server: org.discord_invite_url,
        scrims_won:    org.scrims_won   || 0,
        scrims_lost:   org.scrims_lost  || 0,
        total_scrims:  org.total_scrims || 0,
        avg_tier:      avg_tier,
        roster: players.map do |p|
          {
            summoner_name: p.summoner_name,
            role:          p.role,
            tier:          p.solo_queue_tier
          }
        end
      }
    end
  end
end
