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
    {
      id: @scrim.id,
      organization_id: @scrim.organization_id,
      opponent_team: opponent_team_summary,
      scheduled_at: @scrim.scheduled_at,
      scrim_type: @scrim.scrim_type,
      focus_area: @scrim.focus_area,
      games_planned: @scrim.games_planned,
      games_completed: @scrim.games_completed,
      completion_percentage: @scrim.completion_percentage,
      status: @scrim.status,
      win_rate: @scrim.win_rate,
      is_confidential: @scrim.is_confidential,
      visibility: @scrim.visibility,
      created_at: @scrim.created_at,
      updated_at: @scrim.updated_at
    }
  end

  def detailed_attributes
    {
      match_id: @scrim.match_id,
      pre_game_notes: @scrim.pre_game_notes,
      post_game_notes: @scrim.post_game_notes,
      game_results: @scrim.game_results,
      objectives: @scrim.objectives,
      outcomes: @scrim.outcomes,
      objectives_met: @scrim.objectives_met?
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

    {
      id: @scrim.opponent_team.id,
      name: @scrim.opponent_team.name,
      tag: @scrim.opponent_team.tag,
      tier: @scrim.opponent_team.tier,
      logo_url: @scrim.opponent_team.logo_url
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
