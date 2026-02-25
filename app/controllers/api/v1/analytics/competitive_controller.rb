# frozen_string_literal: true

module Api
  module V1
    module Analytics
      # Competitive analytics endpoints:
      #   GET /api/v1/analytics/competitive/draft-performance
      #   GET /api/v1/analytics/competitive/tournament-stats
      #   GET /api/v1/analytics/competitive/opponents
      #
      # All actions accept the same optional filter params:
      #   tournament  [String]  filter by tournament name
      #   patch       [String]  filter by patch version
      #   region      [String]  filter by tournament region
      #   start_date  [String]  ISO 8601 — lower bound of match_date
      #   end_date    [String]  ISO 8601 — upper bound of match_date
      class CompetitiveController < Api::V1::BaseController
        # ── Draft performance ──────────────────────────────────────────
        # Returns champion pick stats, ban stats, blue/red side win rates,
        # and per-role performance aggregated from competitive_matches.
        def draft_performance
          matches = apply_filters(organization_scoped(CompetitiveMatch))
          total   = matches.count

          return render_success(empty_draft_performance) if total.zero?

          # Load only the columns needed for JSONB aggregation in Ruby
          rows = matches.select(:our_picks, :our_bans, :victory, :side).to_a

          render_success(
            pick_performance: build_pick_performance(rows, total),
            ban_performance:  build_ban_performance(rows, total),
            side_performance: build_side_performance(rows),
            role_performance: build_role_performance(rows),
            meta_champions:   extract_meta_champions(matches),
            total_matches:    total,
            date_range:       build_date_range(matches)
          )
        rescue StandardError => e
          Rails.logger.error("[CompetitiveAnalytics] draft_performance: #{e.message}\n#{e.backtrace.first(3).join("\n")}")
          render_error(message: 'Failed to load draft performance', code: 'INTERNAL_ERROR', status: :internal_server_error)
        end

        # ── Tournament stats ───────────────────────────────────────────
        # Returns per-tournament win/loss breakdown with stage drill-down
        # and patch version history.
        def tournament_stats
          matches      = apply_filters(organization_scoped(CompetitiveMatch))
          total_games  = matches.count
          total_wins   = matches.victories.count
          total_losses = total_games - total_wins

          render_success(
            tournaments:      build_tournament_stats(matches),
            total_games:      total_games,
            total_wins:       total_wins,
            total_losses:     total_losses,
            overall_win_rate: total_games.positive? ? (total_wins.to_f / total_games * 100).round(1) : 0
          )
        rescue StandardError => e
          Rails.logger.error("[CompetitiveAnalytics] tournament_stats: #{e.message}\n#{e.backtrace.first(3).join("\n")}")
          render_error(message: 'Failed to load tournament stats', code: 'INTERNAL_ERROR', status: :internal_server_error)
        end

        # ── Opponent analysis ──────────────────────────────────────────
        # Returns aggregated win/loss record against each unique opponent.
        def opponents
          rows = apply_filters(organization_scoped(CompetitiveMatch))
                   .where.not(opponent_team_name: [nil, ''])
                   .select(:opponent_team_name, :victory, :match_date, :tournament_name)
                   .order(match_date: :desc)
                   .to_a

          opponents_list = build_opponents_data(rows)

          render_success(
            opponents:               opponents_list,
            total_unique_opponents:  opponents_list.size
          )
        rescue StandardError => e
          Rails.logger.error("[CompetitiveAnalytics] opponents: #{e.message}\n#{e.backtrace.first(3).join("\n")}")
          render_error(message: 'Failed to load opponent analysis', code: 'INTERNAL_ERROR', status: :internal_server_error)
        end

        # ── Private helpers ────────────────────────────────────────────
        private

        # Apply all optional query filters to a CompetitiveMatch scope
        def apply_filters(scope)
          scope = scope.by_tournament(params[:tournament]) if params[:tournament].present?
          scope = scope.by_patch(params[:patch])           if params[:patch].present?
          scope = scope.by_region(params[:region])         if params[:region].present?
          if params[:start_date].present? && params[:end_date].present?
            scope = scope.in_date_range(params[:start_date], params[:end_date])
          end
          scope
        end

        # ── draft_performance helpers ──────────────────────────────────

        def build_pick_performance(rows, total_games)
          stats = Hash.new { |h, k| h[k] = { games: 0, wins: 0, role: nil } }

          rows.each do |match|
            won = match.victory
            (match.our_picks || []).each do |pick|
              champ = pick['champion']
              next if champ.blank?

              stats[champ][:games] += 1
              stats[champ][:wins]  += 1 if won
              stats[champ][:role] ||= pick['role']
            end
          end

          stats.map do |champ, s|
            losses = s[:games] - s[:wins]
            {
              champion:  champ,
              games:     s[:games],
              wins:      s[:wins],
              losses:    losses,
              win_rate:  (s[:wins].to_f / s[:games] * 100).round(1),
              role:      s[:role] || 'unknown',
              pick_rate: (s[:games].to_f / total_games * 100).round(1)
            }
          end.sort_by { |s| -s[:games] }
        end

        def build_ban_performance(rows, total_games)
          counts = Hash.new(0)

          rows.each do |match|
            (match.our_bans || []).each do |ban|
              champ = ban['champion']
              counts[champ] += 1 unless champ.blank?
            end
          end

          counts.map do |champ, count|
            {
              champion:  champ,
              ban_count: count,
              ban_rate:  (count.to_f / total_games * 100).round(1)
            }
          end.sort_by { |s| -s[:ban_count] }
        end

        def build_side_performance(rows)
          %w[blue red].each_with_object({}) do |side, result|
            side_rows = rows.select { |m| m.side == side }
            games     = side_rows.size
            wins      = side_rows.count(&:victory)
            result[side] = {
              games:    games,
              wins:     wins,
              losses:   games - wins,
              win_rate: games.positive? ? (wins.to_f / games * 100).round(1) : 0
            }
          end
        end

        def build_role_performance(rows)
          roles      = %w[top jungle mid adc support]
          role_stats = roles.each_with_object({}) do |r, h|
            h[r] = { games: 0, wins: 0, champions: Hash.new(0) }
          end

          rows.each do |match|
            won = match.victory
            (match.our_picks || []).each do |pick|
              role  = pick['role']&.downcase
              champ = pick['champion']
              next unless role_stats.key?(role) && champ.present?

              role_stats[role][:games]          += 1
              role_stats[role][:wins]           += 1 if won
              role_stats[role][:champions][champ] += 1
            end
          end

          role_stats.map do |role, s|
            most_played = s[:champions].max_by { |_, c| c }&.first || 'N/A'
            {
              role:                  role,
              games:                 s[:games],
              wins:                  s[:wins],
              win_rate:              s[:games].positive? ? (s[:wins].to_f / s[:games] * 100).round(1) : 0,
              most_played_champion:  most_played,
              champion_pool_size:    s[:champions].size
            }
          end
        end

        def extract_meta_champions(matches)
          matches.where.not(meta_champions: nil)
                 .pluck(:meta_champions)
                 .flatten
                 .compact
                 .tally
                 .sort_by { |_, count| -count }
                 .first(10)
                 .map(&:first)
        end

        def build_date_range(matches)
          scoped = matches.where.not(match_date: nil)
          return nil unless scoped.exists?

          {
            start: scoped.minimum(:match_date)&.strftime('%Y-%m-%d'),
            end:   scoped.maximum(:match_date)&.strftime('%Y-%m-%d')
          }
        end

        # ── tournament_stats helpers ───────────────────────────────────

        def build_tournament_stats(matches)
          matches.distinct.pluck(:tournament_name).filter_map do |name|
            next if name.blank?

            t_matches = matches.where(tournament_name: name)
            games     = t_matches.count
            next if games.zero?

            wins    = t_matches.victories.count
            losses  = games - wins
            patches = t_matches.where.not(patch_version: nil).distinct.pluck(:patch_version).compact.sort
            t_dates = t_matches.where.not(match_date: nil)

            date_range = if t_dates.exists?
              {
                start: t_dates.minimum(:match_date)&.strftime('%Y-%m-%d'),
                end:   t_dates.maximum(:match_date)&.strftime('%Y-%m-%d')
              }
            end

            {
              name:           name,
              games:          games,
              wins:           wins,
              losses:         losses,
              win_rate:       (wins.to_f / games * 100).round(1),
              stages:         build_stage_stats(t_matches),
              patch_versions: patches,
              date_range:     date_range
            }
          end.sort_by { |t| -t[:games] }
        end

        def build_stage_stats(t_matches)
          t_matches.where.not(tournament_stage: nil)
                   .distinct
                   .pluck(:tournament_stage)
                   .compact
                   .each_with_object({}) do |stage, result|
            s_matches = t_matches.where(tournament_stage: stage)
            games     = s_matches.count
            wins      = s_matches.victories.count
            result[stage] = {
              games:    games,
              wins:     wins,
              losses:   games - wins,
              win_rate: games.positive? ? (wins.to_f / games * 100).round(1) : 0
            }
          end
        end

        # ── opponents helpers ──────────────────────────────────────────

        def build_opponents_data(rows)
          rows.group_by(&:opponent_team_name).map do |name, opp_rows|
            wins        = opp_rows.count(&:victory)
            games       = opp_rows.size
            last_match  = opp_rows.filter_map(&:match_date).max
            tournaments = opp_rows.filter_map(&:tournament_name).uniq.sort

            {
              name:            name,
              matches:         games,
              wins:            wins,
              losses:          games - wins,
              win_rate:        (wins.to_f / games * 100).round(1),
              last_match_date: last_match&.strftime('%Y-%m-%d'),
              tournaments:     tournaments
            }
          end.sort_by { |o| -o[:matches] }
        end

        # ── empty state helpers ────────────────────────────────────────

        def empty_draft_performance
          {
            pick_performance: [],
            ban_performance:  [],
            side_performance: { blue: side_zeros, red: side_zeros },
            role_performance: [],
            meta_champions:   [],
            total_matches:    0
          }
        end

        def side_zeros
          { games: 0, wins: 0, losses: 0, win_rate: 0 }
        end
      end
    end
  end
end
