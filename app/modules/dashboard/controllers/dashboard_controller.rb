# frozen_string_literal: true

module Dashboard
  module Controllers
    class DashboardController < Api::V1::BaseController
      include Analytics::Concerns::AnalyticsCalculations

      def index
        dashboard_data = {
          stats: calculate_stats,
          recent_matches: recent_matches_data,
          upcoming_events: upcoming_events_data,
          active_goals: active_goals_data,
          roster_status: roster_status_data
        }

        render_success(dashboard_data)
      end

      def stats
        # calculate_stats now caches internally — no need to wrap again here
        render_success(calculate_stats)
      end

      def activities
        recent_activities = fetch_recent_activities

        render_success({
                         activities: recent_activities,
                         count: recent_activities.size
                       })
      end

      def schedule
        events = organization_scoped(Schedule)
                 .where('start_time >= ?', Time.current)
                 .order(start_time: :asc)
                 .limit(10)

        render_success({
                         events: ScheduleSerializer.render_as_hash(events),
                         count: events.size
                       })
      end

      private

      # Returns dashboard stats, cached per-org for 5 minutes.
      # Both the `index` and `stats` actions go through here so the cache
      # is shared — only one thread ever runs the queries for a given org.
      def calculate_stats
        Rails.cache.fetch("dashboard_stats_v2_#{current_organization.id}", expires_in: 5.minutes) do
          compute_dashboard_stats
        end
      end

      # Runs the actual DB queries — called only on cache miss.
      # Reduces ~12 individual queries down to 6 by using SQL aggregates.
      def compute_dashboard_stats
        matches = organization_scoped(Match).recent(30)

        # Query 1: match aggregates — total, wins, losses in one pass
        match_row = matches.select(
          'COUNT(*) AS total',
          'COUNT(*) FILTER (WHERE victory) AS wins',
          'COUNT(*) FILTER (WHERE NOT victory) AS losses'
        ).take

        total_matches = match_row&.total.to_i
        wins          = match_row&.wins.to_i
        losses        = match_row&.losses.to_i
        win_rate      = total_matches.zero? ? 0.0 : ((wins.to_f / total_matches) * 100).round(1)

        # Query 2: player counts — total + active in one pass
        # (organization_scoped already adds deleted_at IS NULL)
        player_row = organization_scoped(Player).select(
          "COUNT(*) AS total",
          "COUNT(*) FILTER (WHERE status = 'active') AS active_count"
        ).take

        # Query 3: avg KDA — single aggregate instead of Exists? + 3× SUM
        kda_row = PlayerMatchStat
          .where(match: matches)
          .select('SUM(kills) AS k, SUM(deaths) AS d, SUM(assists) AS a')
          .take
        k = kda_row&.k.to_i; d = kda_row&.d.to_i; a = kda_row&.a.to_i
        avg_kda = ((k + a).to_f / (d.zero? ? 1 : d)).round(2)

        # Query 4: recent form (5 records — small, fine as-is)
        recent_form = calculate_recent_form(matches.order(game_start: :desc).limit(5))

        # Query 5: goal counts — one GROUP BY instead of two COUNTs
        goals_by_status = organization_scoped(TeamGoal).group(:status).count

        # Query 6: upcoming matches
        upcoming_matches = organization_scoped(Schedule)
          .where('start_time >= ? AND event_type = ?', Time.current, 'match')
          .count

        {
          total_players:    player_row&.total.to_i,
          active_players:   player_row&.active_count.to_i,
          total_matches:    total_matches,
          wins:             wins,
          losses:           losses,
          win_rate:         win_rate,
          recent_form:      recent_form,
          avg_kda:          avg_kda,
          active_goals:     goals_by_status['active'].to_i,
          completed_goals:  goals_by_status['completed'].to_i,
          upcoming_matches: upcoming_matches
        }
      end

      # Methods from Analytics::Concerns::AnalyticsCalculations:
      # - calculate_recent_form (used above for recent_form)

      def recent_matches_data
        matches = organization_scoped(Match)
                  .order(game_start: :desc)
                  .limit(5)

        MatchSerializer.render_as_hash(matches)
      end

      def upcoming_events_data
        events = organization_scoped(Schedule)
                 .where('start_time >= ?', Time.current)
                 .order(start_time: :asc)
                 .limit(5)

        ScheduleSerializer.render_as_hash(events)
      end

      def active_goals_data
        goals = organization_scoped(TeamGoal)
                .active
                .order(end_date: :asc)
                .limit(5)

        TeamGoalSerializer.render_as_hash(goals)
      end

      def roster_status_data
        players = organization_scoped(Player).includes(:champion_pools)

        # Order by role to ensure consistent order in by_role hash
        by_role_ordered = players.ordered_by_role.group(:role).count

        {
          by_role: by_role_ordered,
          by_status: players.group(:status).count,
          contracts_expiring: players.contracts_expiring_soon.count
        }
      end

      def fetch_recent_activities
        # Fetch recent audit logs and format them
        activities = AuditLog
                     .where(organization: current_organization)
                     .order(created_at: :desc)
                     .limit(20)

        activities.map do |log|
          {
            id: log.id,
            action: log.action,
            entity_type: log.entity_type,
            entity_id: log.entity_id,
            user: log.user&.email,
            timestamp: log.created_at,
            changes: summarize_changes(log)
          }
        end
      end

      def summarize_changes(log)
        return nil unless log.new_values.present?

        # Only show important field changes
        important_fields = %w[status role summoner_name title victory]
        changes = log.new_values.slice(*important_fields)

        return nil if changes.empty?

        changes
      end
    end
  end
end
