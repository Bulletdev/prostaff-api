# frozen_string_literal: true

# Advances winner and loser to their next matches after a confirmed result.
#
# Uses the FK self-references on TournamentMatch (next_match_winner_id,
# next_match_loser_id) for O(1) lookup — no hardcoded round maps.
#
# @example
#   BracketProgressionService.new(match, winner: team_a, loser: team_b).call
class BracketProgressionService
  def initialize(match, winner:, loser:, status: 'completed')
    @match  = match
    @winner = winner
    @loser  = loser
    @status = status
  end

  def call
    ActiveRecord::Base.transaction do
      finalize_match!
      advance_winner!
      advance_loser!
      check_tournament_complete!
    end
  end

  private

  def finalize_match!
    @match.update!(
      winner: @winner,
      loser: @loser,
      status: @status,
      completed_at: Time.current
    )
  end

  def advance_winner!
    return unless @match.next_match_winner_id

    next_match = TournamentMatch.find_by(id: @match.next_match_winner_id)
    return unless next_match

    # Assign winner to the first available slot (team_a then team_b)
    if next_match.team_a_id.nil?
      next_match.update!(team_a: @winner)
    elsif next_match.team_b_id.nil?
      next_match.update!(team_b: @winner)
    end
  end

  def advance_loser!
    return unless @match.next_match_loser_id

    next_match = TournamentMatch.find_by(id: @match.next_match_loser_id)
    return unless next_match

    # Assign loser to the first available slot
    if next_match.team_a_id.nil?
      next_match.update!(team_a: @loser)
    elsif next_match.team_b_id.nil?
      next_match.update!(team_b: @loser)
    end
  end

  def check_tournament_complete!
    tournament = @match.tournament
    return unless @match.bracket_side == 'grand_final'

    tournament.update!(
      status: 'finished',
      finished_at: Time.current
    )
  end
end
