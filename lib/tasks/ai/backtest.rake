# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
namespace :ai do
  desc 'Backtest AI win probability prediction accuracy. Usage: rake ai:backtest LEAGUE=CBLOL'
  task backtest: :environment do
    league = ENV['LEAGUE']

    all_matches = CompetitiveMatch.unscoped
    all_matches = all_matches.where(tournament_name: league) if league

    all_matches = all_matches.where.not(our_picks: nil).where.not(opponent_picks: nil)
    total = all_matches.count

    if total < 10
      puts "[AI Backtest] Not enough matches (#{total}). Need at least 10."
      next
    end

    puts "[AI Backtest] Total matches: #{total} (league=#{league || 'all'})"

    split       = (total * 0.8).ceil
    train_ids   = all_matches.limit(split).pluck(:id)
    test_matches = all_matches.where.not(id: train_ids)

    puts "[AI Backtest] Training on #{train_ids.size} matches, testing on #{test_matches.count}..."

    # Temporarily rebuild matrix using only training set
    # Note: ChampionMatrixBuilder.delete_all is called inside, using the full table.
    # For backtest we rebuild from scratch with only training data.
    AiChampionMatrix.delete_all
    AiChampionVector.delete_all

    train_matches = CompetitiveMatch.unscoped.where(id: train_ids)
    train_matches.find_each do |match|
      winner_picks = match.victory ? match.our_picks : match.opponent_picks
      loser_picks  = match.victory ? match.opponent_picks : match.our_picks
      next if winner_picks.blank? || loser_picks.blank?

      winner_champions = winner_picks.map { |p| p['champion'] }.compact
      loser_champions  = loser_picks.map  { |p| p['champion'] }.compact

      winner_champions.each do |winner|
        loser_champions.each do |loser|
          AiChampionMatrix.upsert_win(winner, loser)
          AiChampionMatrix
            .find_or_initialize_by(champion_a: loser, champion_b: winner)
            .tap do |m|
            m.total_games = m.total_games.to_i + 1
            m.updated_at = Time.current
            m.save!
          end
        end
      end
    end

    AiIntelligence::ChampionVectorBuilder.rebuild_all!

    correct = 0
    skipped = 0
    tested  = 0

    test_matches.find_each do |match|
      our_champs      = (match.our_picks || []).map { |p| p['champion'] }.compact
      opponent_champs = (match.opponent_picks || []).map { |p| p['champion'] }.compact

      if our_champs.size < 2 || opponent_champs.size < 2
        skipped += 1
        next
      end

      result = AiIntelligence::WinProbabilityCalculator.call(
        team_a: our_champs,
        team_b: opponent_champs,
        synergies: {},
        counters: {}
      )

      predicted_win = result[:score] > 0.5
      actual_win    = match.victory

      correct += 1 if predicted_win == actual_win
      tested  += 1
    end

    if tested.zero?
      puts '[AI Backtest] No testable matches after filtering.'
      next
    end

    accuracy = (correct.to_f / tested * 100).round(2)
    puts "[AI Backtest] Results: #{correct}/#{tested} correct | Accuracy: #{accuracy}% | Skipped: #{skipped}"
    puts accuracy >= 58.0 ? '[AI Backtest] PASS (target: 58%)' : '[AI Backtest] FAIL (target: 58%)'
  end
end
# rubocop:enable Metrics/BlockLength
