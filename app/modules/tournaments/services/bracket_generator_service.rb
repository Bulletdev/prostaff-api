# frozen_string_literal: true

# Generates a full 16-team Double Elimination bracket.
#
# Structure:
#   Upper Bracket (UB): 4 rounds → UB R1 (8 matches), UB R2 (4), UB Semis (2), UB Final (1)
#   Lower Bracket (LB): 6 rounds → LB R1 (4), LB R2 (4), LB R3 (2), LB R4 (2), LB Semis (1), LB Final (1)
#   Grand Final (GF): 1 match
#   Total: 8+4+2+1 + 4+4+2+2+1+1 + 1 = 15 UB + 14 LB + 1 GF = 30 matches
#   (For 16 teams: 15 UB + 14 LB + 1 GF = 30 total — each team can lose twice before elimination)
#
# FK self-references enable O(1) bracket progression:
#   TournamentMatch.next_match_winner_id → where winner advances
#   TournamentMatch.next_match_loser_id  → where loser drops (nil = eliminated)
#
# @example
#   BracketGeneratorService.new(tournament).call
#   # => Array of TournamentMatch
class BracketGeneratorService
  UB_ROUNDS = [
    { label: 'UB Round 1',   order: 1, matches: 8 },
    { label: 'UB Round 2',   order: 2, matches: 4 },
    { label: 'UB Semifinals', order: 3, matches: 2 },
    { label: 'UB Final', order: 4, matches: 1 }
  ].freeze

  LB_ROUNDS = [
    { label: 'LB Round 1',    order: 5,  matches: 4 },
    { label: 'LB Round 2',    order: 6,  matches: 4 },
    { label: 'LB Round 3',    order: 7,  matches: 2 },
    { label: 'LB Round 4',    order: 8,  matches: 2 },
    { label: 'LB Semifinals', order: 9,  matches: 1 },
    { label: 'LB Final',      order: 10, matches: 1 }
  ].freeze

  GF_ROUND = { label: 'Grand Final', order: 11, matches: 1 }.freeze

  def initialize(tournament)
    @tournament = tournament
  end

  def call
    raise "Bracket already generated for tournament #{@tournament.id}" if @tournament.bracket_generated?

    ActiveRecord::Base.transaction do
      matches = build_all_matches
      wire_bracket(matches)
      matches
    end
  end

  private

  def build_all_matches
    all = {}
    match_number = 1

    UB_ROUNDS.each do |round|
      all[round[:label]], match_number = build_round_matches('upper', round, match_number)
    end

    LB_ROUNDS.each do |round|
      all[round[:label]], match_number = build_round_matches('lower', round, match_number)
    end

    all[GF_ROUND[:label]] = [create_match('grand_final', GF_ROUND, match_number)]
    all
  end

  def build_round_matches(side, round, start_number)
    number = start_number
    matches = round[:matches].times.map do
      m = create_match(side, round, number)
      number += 1
      m
    end
    [matches, number]
  end

  def create_match(side, round, match_number)
    TournamentMatch.create!(
      tournament: @tournament,
      bracket_side: side,
      round_label: round[:label],
      round_order: round[:order],
      match_number: match_number,
      bo_format: @tournament.bo_format,
      status: 'scheduled'
    )
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def wire_bracket(all)
    ubr1 = all['UB Round 1']     # 8 matches
    ubr2 = all['UB Round 2']     # 4 matches
    ubsf = all['UB Semifinals']  # 2 matches
    ubf  = all['UB Final']       # 1 match

    lbr1 = all['LB Round 1']    # 4 matches (8 UBR1 losers)
    lbr2 = all['LB Round 2']    # 4 matches (LBR1 winner vs UBR2 loser)
    lbr3 = all['LB Round 3']    # 2 matches (LBR2 winners)
    lbr4 = all['LB Round 4']    # 2 matches (LBR3 winner vs UBSF loser)
    lbsf = all['LB Semifinals'] # 1 match  (LBR4 winners)
    lbf  = all['LB Final']      # 1 match  (LBSF winner vs UBF loser)
    gf   = all['Grand Final']   # 1 match  (UBF winner vs LBF winner)

    # UB R1: pairs (0,1), (2,3), (4,5), (6,7) feed UBR2[0..3]
    # UB R1 losers: pairs (0,1), (2,3), (4,5), (6,7) feed LBR1[0..3]
    ubr1.each_with_index do |m, i|
      m.update!(
        next_match_winner_id: ubr2[i / 2].id,
        next_match_loser_id: lbr1[i / 2].id
      )
    end

    # UB R2: pairs (0,1), (2,3) feed UBSF[0..1]
    # UB R2 losers feed LBR2[0..3] — each UBR2 loser meets an LBR1 winner
    ubr2.each_with_index do |m, i|
      m.update!(
        next_match_winner_id: ubsf[i / 2].id,
        next_match_loser_id: lbr2[i].id
      )
    end

    # LB R1 winners also feed LBR2 (same match, other slot)
    lbr1.each_with_index do |m, i|
      m.update!(next_match_winner_id: lbr2[i].id)
      # LBR1 losers are eliminated (next_match_loser_id stays nil)
    end

    # LB R2 winners: pairs (0,1), (2,3) feed LBR3[0..1]
    lbr2.each_with_index do |m, i|
      m.update!(next_match_winner_id: lbr3[i / 2].id)
      # LBR2 losers are eliminated
    end

    # UB Semis: winners → UB Final; losers → LBR4[0..1]
    ubsf.each_with_index do |m, i|
      m.update!(
        next_match_winner_id: ubf[0].id,
        next_match_loser_id: lbr4[i].id
      )
    end

    # LB R3 winners feed LBR4 (other slot — UBSF loser is the seeded side)
    lbr3.each_with_index do |m, i|
      m.update!(next_match_winner_id: lbr4[i].id)
      # LBR3 losers are eliminated
    end

    # LB R4 winners → LBSF; losers eliminated
    lbr4.each do |m|
      m.update!(next_match_winner_id: lbsf[0].id)
    end

    # UB Final: winner → GF; loser → LB Final
    ubf[0].update!(
      next_match_winner_id: gf[0].id,
      next_match_loser_id: lbf[0].id
    )

    # LB Semifinals → LB Final
    lbsf[0].update!(next_match_winner_id: lbf[0].id)

    # LB Final → Grand Final
    lbf[0].update!(next_match_winner_id: gf[0].id)

    # Grand Final: no next matches (nil) — tournament ends
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
end
