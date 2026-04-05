# frozen_string_literal: true

# Serializer for Scrim model
# Renders practice match data and results
class ScrimSerializer
  def initialize(scrim, options = {})
    @scrim = scrim
    @options = options
  end

  def as_json
    base_attributes.tap do |hash|
      hash.merge!(detailed_attributes) if @options[:detailed]
      hash.merge!(calendar_attributes) if @options[:calendar_view]
    end
  end

  private

  def base_attributes
    scrim_fields.merge(stats_fields).merge(timestamps_fields)
  end

  def scrim_fields
    {
      id: @scrim.id,
      organization_id: @scrim.organization_id,
      opponent_team: opponent_team_summary,
      scheduled_at: @scrim.scheduled_at,
      scrim_type: @scrim.scrim_type,
      focus_area: @scrim.focus_area,
      draft_type: @scrim.draft_type
    }
  end

  def stats_fields
    {
      games_planned: @scrim.games_planned,
      games_completed: @scrim.games_completed,
      completion_percentage: @scrim.completion_percentage,
      status: @scrim.status,
      win_rate: @scrim.win_rate,
      is_confidential: @scrim.is_confidential,
      visibility: @scrim.visibility
    }
  end

  def timestamps_fields
    {
      created_at: @scrim.created_at,
      updated_at: @scrim.updated_at
    }
  end

  def detailed_attributes
    {
      match_id:       @scrim.match_id,
      pre_game_notes: @scrim.pre_game_notes,
      post_game_notes: @scrim.post_game_notes,
      game_results:   @scrim.game_results,
      objectives:     @scrim.objectives,
      outcomes:       @scrim.outcomes,
      objectives_met: @scrim.objectives_met?,
      opponent_detail: opponent_detail,
      head_to_head:   head_to_head
    }
  end

  TIER_SCORE = {
    'CHALLENGER' => 9, 'GRANDMASTER' => 8, 'MASTER'   => 7,
    'DIAMOND'    => 6, 'EMERALD'     => 5, 'PLATINUM' => 4,
    'GOLD'       => 3, 'SILVER'      => 2, 'BRONZE'   => 1
  }.freeze

  TIER_LABEL = {
    9 => 'Challenger', 8 => 'Grandmaster', 7 => 'Master',
    6 => 'Diamond',    5 => 'Emerald',     4 => 'Platinum',
    3 => 'Gold',       2 => 'Silver',      1 => 'Bronze', 0 => 'Iron'
  }.freeze

  def opponent_detail
    return nil unless @scrim.opponent_team

    t = @scrim.opponent_team

    # Try to find the registered Organization with the same name
    org = Organization.unscoped.find_by(name: t.name)
    roster, avg_tier = org_roster_and_avg(org)

    {
      league:          t.league,
      discord_server:  t.discord_server || org&.discord_invite_url,
      known_players:   Array(t.known_players),
      playstyle_notes: t.playstyle_notes,
      strengths:       Array(t.strengths),
      weaknesses:      Array(t.weaknesses),
      roster:          roster,
      avg_tier:        avg_tier
    }
  end

  def org_roster_and_avg(org)
    return [[], nil] unless org

    players = org.players.active.select(:summoner_name, :role, :solo_queue_tier)
    scores  = players.map { |p| TIER_SCORE[p.solo_queue_tier.to_s.upcase] || 0 }
    avg     = scores.empty? ? nil : TIER_LABEL[(scores.sum.to_f / scores.size).round]

    roster = players.map { |p| { summoner_name: p.summoner_name, role: p.role, tier: p.solo_queue_tier } }
    [roster, avg]
  end

  def head_to_head
    return nil unless @scrim.opponent_team_id

    past = Scrim.unscoped
                .where(organization_id: @scrim.organization_id,
                       opponent_team_id: @scrim.opponent_team_id)
                .where.not(id: @scrim.id)
                .where.not(games_completed: nil)
                .where('games_completed >= games_planned')
                .order(scheduled_at: :desc)
                .limit(10)
                .to_a

    wins   = past.count { |s| s.win_rate.to_f >= 50 }
    losses = past.count - wins

    {
      wins:   wins,
      losses: losses,
      total:  past.count
    }
  end

  def calendar_attributes
    {
      title: calendar_title,
      start: @scrim.scheduled_at,
      end: @scrim.scheduled_at + (@scrim.games_planned || 3).hours,
      color: status_color
    }
  end

  def opponent_team_summary
    return nil unless @scrim.opponent_team

    t = @scrim.opponent_team
    {
      id:          t.id,
      name:        t.name,
      tag:         t.tag,
      tier:        t.tier,
      region:      t.region,
      scrims_won:  t.scrims_won  || 0,
      scrims_lost: t.scrims_lost || 0,
      logo_url:    t.logo_url
    }
  end

  def calendar_title
    opponent = @scrim.opponent_team&.name || 'TBD'
    "Scrim vs #{opponent}"
  end

  def status_color
    case @scrim.status
    when 'completed'
      '#4CAF50' # Green
    when 'in_progress'
      '#FF9800' # Orange
    when 'upcoming'
      '#2196F3' # Blue
    else
      '#9E9E9E' # Gray
    end
  end
end
