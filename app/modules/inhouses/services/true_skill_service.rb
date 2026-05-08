# frozen_string_literal: true

# Pure-Ruby implementation of the TrueSkill 2-team update algorithm.
#
# Ported from the inhouse_bot reference (Python/trueskill library) and the
# original Microsoft whitepaper. No external gem dependency.
#
# Usage:
#   result = TrueSkillService.update(blue_ratings, red_ratings, winner: 'blue')
#   result[:blue]  # => [{ mu:, sigma: }, ...]
#   result[:red]   # => [{ mu:, sigma: }, ...]
#
#   prob = TrueSkillService.win_probability(blue_ratings, red_ratings)
#   # => 0.63  (63% chance blue wins)
#
class TrueSkillService
  MU    = 25.0
  SIGMA = MU / 3.0         # ≈ 8.333
  BETA  = MU / 6.0         # ≈ 4.167 — performance noise
  TAU   = MU / 300.0       # ≈ 0.083 — dynamics (uncertainty floor per game)
  SIGMA_MIN = 0.5 # Never let σ drop below this (prevents rating lock)

  Rating = Struct.new(:mu, :sigma)

  # Compute the probability that blue team wins.
  # @param blue [Array<Rating>]
  # @param red  [Array<Rating>]
  # @return [Float] probability in 0..1
  def self.win_probability(blue, red)
    all = blue + red
    sum_sigma_sq = all.sum { |r| r.sigma**2 } + (all.size * (BETA**2))
    delta_mu = blue.sum(&:mu) - red.sum(&:mu)
    phi(delta_mu / Math.sqrt(sum_sigma_sq))
  end

  # Update ratings after a 2-team game.
  # @param blue   [Array<Rating>]
  # @param red    [Array<Rating>]
  # @param winner [String] 'blue' or 'red'
  # @return [Hash] { blue: [{ mu:, sigma: }], red: [...] }
  def self.update(blue, red, winner:)
    blue = apply_dynamics(blue)
    red  = apply_dynamics(red)

    c_sq, c = compute_c(blue + red)
    winner_team, loser_team = winner == 'blue' ? [blue, red] : [red, blue]
    norm_t = (winner_team.sum(&:mu) - loser_team.sum(&:mu)) / c
    vt = v_func(norm_t)
    wt = w_func(norm_t)

    new_winners = update_team(winner_team, c, c_sq, vt, wt, won: true)
    new_losers  = update_team(loser_team,  c, c_sq, vt, wt, won: false)

    winner == 'blue' ? { blue: new_winners, red: new_losers } : { blue: new_losers, red: new_winners }
  end

  # Persist rating updates for all participants in a completed game.
  # Reads participant roles and current ratings, runs the update, saves all.
  #
  # @param inhouse  [Inhouse]
  # @param winner   [String] 'blue' or 'red'
  def self.update_ratings(inhouse, winner)
    participations = inhouse.inhouse_participations.includes(:player).where.not(team: 'none').to_a
    blue_parts = participations.select { |p| p.team == 'blue' }
    red_parts  = participations.select { |p| p.team == 'red' }

    org = inhouse.organization

    blue_ratings_data = load_ratings(blue_parts, org)
    red_ratings_data  = load_ratings(red_parts, org)

    blue_structs = blue_ratings_data.map { |d| Rating.new(d[:rating].mu, d[:rating].sigma) }
    red_structs  = red_ratings_data.map  { |d| Rating.new(d[:rating].mu, d[:rating].sigma) }

    result = update(blue_structs, red_structs, winner: winner)

    ActiveRecord::Base.transaction do
      persist_updates(blue_parts, blue_ratings_data, result[:blue], winner: winner, team: 'blue', game_winner: winner)
      persist_updates(red_parts,  red_ratings_data,  result[:red],  winner: winner, team: 'red',  game_winner: winner)
    end
  end

  # ── Private helpers ───────────────────────────────────────────────

  def self.apply_dynamics(team)
    team.map { |r| Rating.new(r.mu, Math.sqrt((r.sigma**2) + (TAU**2))) }
  end
  private_class_method :apply_dynamics

  def self.compute_c(all_ratings)
    sum_sigma_sq = all_ratings.sum { |r| r.sigma**2 }
    c_sq = (2.0 * (BETA**2)) + sum_sigma_sq
    [c_sq, Math.sqrt(c_sq)]
  end
  private_class_method :compute_c

  def self.update_team(team, c_val, c_sq, v_factor, w_factor, won:)
    team.map do |r|
      rank_mult = (r.sigma**2) / c_val
      new_mu    = won ? r.mu + (rank_mult * v_factor) : r.mu - (rank_mult * v_factor)
      raw_sigma = r.sigma * Math.sqrt([1.0 - (((r.sigma**2) / c_sq) * w_factor), 0.0001].max)
      new_sigma = [raw_sigma, SIGMA_MIN].max
      { mu: new_mu.round(6), sigma: new_sigma.round(6) }
    end
  end
  private_class_method :update_team

  # Normal CDF (Phi function)
  def self.phi(val)
    0.5 * (1.0 + Math.erf(val / Math.sqrt(2.0)))
  end
  private_class_method :phi

  # Normal PDF
  def self.pdf(val)
    Math.exp(-(val**2) / 2.0) / Math.sqrt(2.0 * Math::PI)
  end
  private_class_method :pdf

  # Additive correction factor. `norm_t` is (delta_mu / c); draw_eps is 0 for LoL.
  def self.v_func(norm_t, draw_eps = 0.0)
    diff = norm_t - draw_eps
    if diff > -10
      pdf(diff) / phi(diff)
    else
      -diff
    end
  end
  private_class_method :v_func

  # Multiplicative correction factor.
  def self.w_func(norm_t, draw_eps = 0.0)
    diff = norm_t - draw_eps
    vt   = v_func(norm_t, draw_eps)
    if diff > -10
      vt * (vt + diff)
    else
      1.0
    end
  end
  private_class_method :w_func

  # Load or initialise PlayerInhouseRating for each participation
  def self.load_ratings(participations, org)
    participations.map do |p|
      role   = p.role.presence || p.player&.role || 'fill'
      rating = PlayerInhouseRating.for(p.player, role, org)
      rating.save! if rating.new_record?
      { participation: p, rating: rating, role: role }
    end
  end
  private_class_method :load_ratings

  # Apply new mu/sigma values and update win/loss counts
  def self.persist_updates(participations, ratings_data, new_values, team:, game_winner:, winner: nil)
    won = (team == game_winner)

    participations.each_with_index do |_p, i|
      data   = ratings_data[i]
      rating = data[:rating]
      new_v  = new_values[i]

      old_mmr = compute_mmr(rating.mu, rating.sigma)

      # Capture rating snapshot before the update
      data[:participation].update_columns(
        mu_snapshot: rating.mu,
        sigma_snapshot: rating.sigma
      )

      rating.mu = new_v[:mu]
      rating.sigma = new_v[:sigma]
      rating.games_played += 1
      won ? rating.wins += 1 : rating.losses += 1
      rating.save!

      new_mmr = compute_mmr(rating.mu, rating.sigma)
      data[:participation].update_columns(mmr_delta: new_mmr - old_mmr)
    end
  end
  private_class_method :persist_updates

  def self.compute_mmr(mu_val, sigma_val)
    [((mu_val - (3.0 * sigma_val)) * 100).round, 0].max
  end
  private_class_method :compute_mmr
end
