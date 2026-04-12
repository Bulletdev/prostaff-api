# frozen_string_literal: true

# Serializes a Tournament. Use with_bracket: true to include all match data.
class TournamentSerializer
  def initialize(tournament, options = {})
    @tournament = tournament
    @options    = options
  end

  def as_json
    base.tap do |h|
      h[:matches] = serialize_matches if @options[:with_bracket]
    end
  end

  private

  def base
    core_fields.merge(fee_fields).merge(schedule_fields)
  end

  def core_fields
    {
      id: @tournament.id,
      name: @tournament.name,
      game: @tournament.game,
      format: @tournament.format,
      status: @tournament.status,
      max_teams: @tournament.max_teams,
      enrolled_teams_count: @tournament.enrolled_teams_count,
      bo_format: @tournament.bo_format,
      current_round_label: @tournament.current_round_label,
      rules: @tournament.rules
    }
  end

  def fee_fields
    {
      entry_fee_cents: @tournament.entry_fee_cents,
      prize_pool_cents: @tournament.prize_pool_cents
    }
  end

  def schedule_fields
    {
      registration_closes_at: @tournament.registration_closes_at&.iso8601,
      scheduled_start_at: @tournament.scheduled_start_at&.iso8601,
      started_at: @tournament.started_at&.iso8601,
      finished_at: @tournament.finished_at&.iso8601,
      created_at: @tournament.created_at.iso8601
    }
  end

  def serialize_matches
    @tournament.tournament_matches
               .includes(:team_a, :team_b, :winner, :loser)
               .by_round
               .map { |m| TournamentMatchSerializer.new(m).as_json }
  end
end
