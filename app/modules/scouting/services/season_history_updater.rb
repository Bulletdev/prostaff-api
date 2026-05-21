# frozen_string_literal: true

# Maintains a cumulative season history on a scouting target.
#
# Each call records the current season's ranked stats (wins, losses, tier, LP).
# If an entry for the current season already exists it is updated in place.
# Older entries are preserved so history accumulates across syncs.
#
# Season numbering follows Riot's convention: Season N = year - 2010
# (2024=S14, 2025=S15, 2026=S16, …)
class SeasonHistoryUpdater
  def self.call(target:, league_data:)
    new(target: target, league_data: league_data).call
  end

  def initialize(target:, league_data:)
    @target = target
    @league_data = league_data
  end

  def call
    solo = @league_data[:solo_queue]
    return unless solo.present?

    entry = build_entry(solo)
    history = (@target.season_history || []).map(&:symbolize_keys)

    existing_idx = history.find_index { |e| e[:season] == entry[:season] }
    if existing_idx
      history[existing_idx] = entry
    else
      history.unshift(entry)
    end

    @target.update!(season_history: history)
  end

  private

  def build_entry(solo)
    wins   = solo[:wins].to_i
    losses = solo[:losses].to_i
    total  = wins + losses
    wr     = total.positive? ? (wins.to_f / total * 100).round(1) : nil

    {
      season: current_season_label,
      tier: solo[:tier],
      rank: solo[:rank],
      lp: solo[:lp].to_i,
      wins: wins,
      losses: losses,
      win_rate: wr,
      date: Time.current.to_date.iso8601
    }
  end

  def current_season_label
    "S#{Time.current.year - 2010}"
  end
end
