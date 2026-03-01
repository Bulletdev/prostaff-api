# frozen_string_literal: true

module Api
  module V1
    module Analytics
      # Objective Analytics Controller
      #
      # Aggregates tower, dragon, baron, and inhibitor control metrics from the
      # organization's match history. All fields come from pre-stored columns on
      # the matches table — no additional joins are required.
      #
      # @example GET /api/v1/analytics/objectives?match_type=official&date_from=2025-01-01
      #   {
      #     dragon_control: { avg_dragons_per_game: 3.2, dragon_soul_rate: 0.48, ... },
      #     baron_control:  { avg_barons_per_game: 1.4, baron_advantage_rate: 0.68, ... },
      #     tower_control:  { avg_towers_per_game: 7.2, first_tower_rate: 0.56, ... },
      #     objective_score: { overall: 72.4, trend: [...] }
      #   }
      #
      # Query parameters (all optional):
      #   match_type  — e.g. "official", "scrim"
      #   date_from   — ISO 8601 date string (inclusive lower bound on game_start)
      #   date_to     — ISO 8601 date string (inclusive upper bound on game_start)
      #
      class ObjectivesController < Api::V1::BaseController
        def index
          matches = Match.where(organization: current_organization)
          matches = matches.where(match_type: params[:match_type]) if params[:match_type].present?
          matches = matches.where('game_start >= ?', params[:date_from])  if params[:date_from].present?
          matches = matches.where('game_start <= ?', params[:date_to])    if params[:date_to].present?

          total = matches.count
          return render_success(empty_response) if total.zero?

          render_success({
                           dragon_control: build_dragon_stats(matches, total),
                           baron_control: build_baron_stats(matches, total),
                           tower_control: build_tower_stats(matches, total),
                           inhibitor_control: build_inhibitor_stats(matches, total),
                           objective_score: build_objective_score(matches, total)
                         })
        end

        private

        # ---------------------------------------------------------------------------
        # Dragon
        # ---------------------------------------------------------------------------

        def build_dragon_stats(matches, total)
          wins   = matches.where(victory: true)
          losses = matches.where(victory: false)

          {
            avg_dragons_per_game: matches.average(:our_dragons)&.round(2),
            avg_opponent_dragons: matches.average(:opponent_dragons)&.round(2),
            dragon_advantage_rate: rate(matches.where('our_dragons > opponent_dragons').count, total),
            dragon_soul_games: matches.where('our_dragons >= 4').count,
            dragon_soul_rate: rate(matches.where('our_dragons >= 4').count, total),
            by_result: {
              wins: { avg_dragons: wins.average(:our_dragons)&.round(2) },
              losses: { avg_dragons: losses.average(:our_dragons)&.round(2) }
            }
          }
        end

        # ---------------------------------------------------------------------------
        # Baron
        # ---------------------------------------------------------------------------

        def build_baron_stats(matches, total)
          {
            avg_barons_per_game: matches.average(:our_barons)&.round(2),
            avg_opponent_barons: matches.average(:opponent_barons)&.round(2),
            baron_advantage_rate: rate(matches.where('our_barons > opponent_barons').count, total),
            # Baron after loss: games where enemy had more barons but we still won
            baron_comeback_rate: rate(
              matches.where(victory: true).where('our_barons < opponent_barons').count,
              matches.where(victory: true).count
            )
          }
        end

        # ---------------------------------------------------------------------------
        # Tower
        # ---------------------------------------------------------------------------

        def build_tower_stats(matches, total)
          wins = matches.where(victory: true)

          {
            avg_towers_per_game: matches.average(:our_towers)&.round(2),
            avg_opponent_towers: matches.average(:opponent_towers)&.round(2),
            tower_advantage_rate: rate(matches.where('our_towers > opponent_towers').count, total),
            tower_lead_win_rate: rate(
              wins.where('our_towers > opponent_towers').count,
              matches.where('our_towers > opponent_towers').count
            )
          }
        end

        # ---------------------------------------------------------------------------
        # Inhibitor
        # ---------------------------------------------------------------------------

        def build_inhibitor_stats(matches, total)
          {
            avg_inhibitors_per_game: matches.average(:our_inhibitors)&.round(2),
            avg_opponent_inhibitors: matches.average(:opponent_inhibitors)&.round(2),
            inhibitor_advantage_rate: rate(
              matches.where('our_inhibitors > opponent_inhibitors').count,
              total
            )
          }
        end

        # ---------------------------------------------------------------------------
        # Composite objective score
        #
        # Weighted average across four control categories (0–100 scale):
        #   Dragons  30% | Barons  30% | Towers  25% | Inhibitors  15%
        # ---------------------------------------------------------------------------

        def build_objective_score(matches, total)
          dragon_adv  = rate(matches.where('our_dragons > opponent_dragons').count,    total)
          baron_adv   = rate(matches.where('our_barons > opponent_barons').count,      total)
          tower_adv   = rate(matches.where('our_towers > opponent_towers').count,      total)
          inhib_adv   = rate(matches.where('our_inhibitors > opponent_inhibitors').count, total)

          overall = ((dragon_adv * 30) + (baron_adv * 30) + (tower_adv * 25) + (inhib_adv * 15)).round(1)

          {
            overall: overall,
            breakdown: {
              dragon_contribution: (dragon_adv * 30).round(1),
              baron_contribution: (baron_adv  * 30).round(1),
              tower_contribution: (tower_adv  * 25).round(1),
              inhibitor_contribution: (inhib_adv * 15).round(1)
            },
            trend: build_objective_trend(matches)
          }
        end

        def build_objective_trend(matches)
          matches.includes(:match)
                 .order('game_start ASC')
                 .last(30)
                 .map do |m|
            next unless m.game_start

            {
              date: m.game_start.strftime('%Y-%m-%d'),
              our_dragons: m.our_dragons,
              opponent_dragons: m.opponent_dragons,
              our_barons: m.our_barons,
              opponent_barons: m.opponent_barons,
              our_towers: m.our_towers,
              opponent_towers: m.opponent_towers,
              victory: m.victory
            }
          end.compact
        end

        # ---------------------------------------------------------------------------
        # Helpers
        # ---------------------------------------------------------------------------

        def rate(numerator, denominator)
          return 0.0 if denominator.zero?

          (numerator.to_f / denominator).round(2)
        end

        def empty_response
          {
            dragon_control: nil,
            baron_control: nil,
            tower_control: nil,
            inhibitor_control: nil,
            objective_score: nil,
            message: 'No matches found for the given filters'
          }
        end
      end
    end
  end
end
