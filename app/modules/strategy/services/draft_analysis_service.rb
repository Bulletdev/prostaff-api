# frozen_string_literal: true

module Strategy
  module Services
    # Service for analyzing draft plans and providing strategic insights
    # Integrates with scouting data and champion information
    class DraftAnalysisService
      # Analyze a draft plan and provide comprehensive insights
      # @param draft_plan [DraftPlan] The draft plan to analyze
      # @return [Hash] Analysis results with recommendations
      def self.analyze(draft_plan)
        new(draft_plan).analyze
      end

      def initialize(draft_plan)
        @draft_plan = draft_plan
      end

      def analyze
        {
          coverage_analysis: coverage_analysis,
          comfort_picks_analysis: comfort_picks_analysis,
          ban_recommendations: ban_recommendations,
          pick_recommendations: pick_recommendations,
          scenario_completeness: scenario_completeness,
          side_advantages: side_advantages,
          risk_assessment: risk_assessment
        }
      end

      # Get champion assets from Data Dragon
      # @param champion_name [String] Champion name
      # @return [Hash] Champion icon URL and splash art
      def self.champion_assets(champion_name)
        {
          icon: DataDragonService.champion_icon_url(champion_name),
          splash: DataDragonService.champion_splash_url(champion_name),
          loading: DataDragonService.champion_loading_url(champion_name)
        }
      rescue StandardError => e
        Rails.logger.error("Failed to fetch champion assets for #{champion_name}: #{e.message}")
        {
          icon: nil,
          splash: nil,
          loading: nil
        }
      end

      # Get map assets from Data Dragon
      # @return [Hash] Map URLs
      def self.map_assets
        {
          summoners_rift: DataDragonService.map_url('summoners_rift'),
          minimap: DataDragonService.minimap_url
        }
      rescue StandardError => e
        Rails.logger.error("Failed to fetch map assets: #{e.message}")
        {
          summoners_rift: nil,
          minimap: nil
        }
      end

      private

      def coverage_analysis
        total_scenarios = @draft_plan.total_scenarios
        roles_covered = @draft_plan.priority_picks.keys.size

        {
          total_scenarios: total_scenarios,
          roles_with_priority_picks: roles_covered,
          blind_pick_ready: @draft_plan.blind_pick_ready?,
          coverage_percentage: @draft_plan.scenario_coverage,
          status: coverage_status(total_scenarios, roles_covered)
        }
      end

      def coverage_status(scenarios, roles)
        return 'excellent' if scenarios >= 10 && roles == 5
        return 'good' if scenarios >= 5 && roles >= 3
        return 'needs_improvement' if scenarios >= 3
        'incomplete'
      end

      def comfort_picks_analysis
        comfort_picks = @draft_plan.opponent_comfort_picks
        our_bans = @draft_plan.our_bans || []

        banned_comfort_picks = comfort_picks & our_bans
        unbanned_comfort_picks = comfort_picks - our_bans

        {
          total_comfort_picks: comfort_picks.size,
          banned_count: banned_comfort_picks.size,
          unbanned_count: unbanned_comfort_picks.size,
          banned_champions: banned_comfort_picks,
          unbanned_champions: unbanned_comfort_picks,
          coverage_percentage: @draft_plan.comfort_picks_coverage
        }
      end

      def ban_recommendations
        suggested = @draft_plan.suggest_bans
        current_bans = @draft_plan.our_bans || []

        {
          current_bans: current_bans,
          suggested_additions: suggested,
          available_ban_slots: 5 - current_bans.size,
          priority_level: ban_priority_level(current_bans.size, suggested.size)
        }
      end

      def ban_priority_level(current, suggested)
        return 'low' if suggested.zero?
        return 'high' if current < 3 && suggested > 2
        'medium'
      end

      def pick_recommendations
        missing_roles = Constants::Player::ROLES - (@draft_plan.priority_picks&.keys || [])

        {
          priority_picks: @draft_plan.priority_picks,
          missing_roles: missing_roles,
          recommendations: generate_pick_recommendations(missing_roles)
        }
      end

      def generate_pick_recommendations(missing_roles)
        # This could integrate with meta data or scouting
        # For now, we'll return a basic structure
        missing_roles.map do |role|
          {
            role: role,
            suggestion: "Add priority pick for #{role}",
            reasoning: "No priority pick defined for this role"
          }
        end
      end

      def scenario_completeness
        scenarios = @draft_plan.if_then_scenarios || []

        {
          total_scenarios: scenarios.size,
          scenarios_with_notes: scenarios.count { |s| s['note'].present? },
          common_scenarios_covered: check_common_scenarios(scenarios),
          missing_common_scenarios: missing_common_scenarios(scenarios)
        }
      end

      def check_common_scenarios(scenarios)
        common_triggers = %w[
          enemy_bans_carry
          enemy_first_pick
          enemy_bans_comfort
          enemy_takes_flex_pick
        ]

        scenarios.count { |s| common_triggers.any? { |trigger| s['trigger']&.include?(trigger) } }
      end

      def missing_common_scenarios(scenarios)
        common_scenarios = [
          { trigger: 'enemy_bans_carry', description: 'When enemy bans your star player\'s champion' },
          { trigger: 'enemy_first_pick', description: 'Enemy has first pick advantage' },
          { trigger: 'enemy_takes_flex_pick', description: 'Enemy picks a flex champion (multi-role)' }
        ]

        existing_triggers = scenarios.map { |s| s['trigger'] }.compact

        common_scenarios.reject do |scenario|
          existing_triggers.any? { |trigger| trigger.include?(scenario[:trigger]) }
        end
      end

      def side_advantages
        side = @draft_plan.side

        {
          current_side: side,
          advantages: side_specific_advantages(side),
          disadvantages: side_specific_disadvantages(side),
          recommendations: side_recommendations(side)
        }
      end

      def side_specific_advantages(side)
        case side
        when 'blue'
          [
            'First pick advantage',
            'Better access to top side jungle',
            'More open bot lane positioning'
          ]
        when 'red'
          [
            'Counter pick advantage in crucial roles',
            'Last pick allows for flex adaptations',
            'Better access to dragon pit'
          ]
        else
          []
        end
      end

      def side_specific_disadvantages(side)
        case side
        when 'blue'
          [
            'Must commit picks earlier',
            'Less counter-pick flexibility',
            'Dragon control harder to contest'
          ]
        when 'red'
          [
            'Enemy gets first pick',
            'Baron approach more vulnerable',
            'Top lane pressure harder to establish'
          ]
        else
          []
        end
      end

      def side_recommendations(side)
        case side
        when 'blue'
          [
            'Use first pick to secure high-priority meta champion',
            'Consider blind-pickable champions for early picks',
            'Ban enemy comfort picks to reduce their advantage'
          ]
        when 'red'
          [
            'Save counter picks for key roles (typically mid/top)',
            'Use flex picks to hide true composition until last pick',
            'Ban meta priority picks to deny blue side first pick value'
          ]
        else
          []
        end
      end

      def risk_assessment
        risks = []
        risks << 'No if-then scenarios defined' if @draft_plan.total_scenarios.zero?
        risks << 'Less than 3 bans defined' if (@draft_plan.our_bans&.size || 0) < 3
        risks << 'Not all roles have priority picks' unless @draft_plan.blind_pick_ready?
        risks << 'No patch version specified' if @draft_plan.patch_version.blank?

        {
          risk_level: calculate_risk_level(risks.size),
          total_risks: risks.size,
          risks: risks,
          readiness_score: calculate_readiness_score
        }
      end

      def calculate_risk_level(risk_count)
        return 'low' if risk_count.zero?
        return 'medium' if risk_count <= 2
        'high'
      end

      def calculate_readiness_score
        score = 100
        score -= 25 unless @draft_plan.blind_pick_ready?
        score -= 20 if @draft_plan.total_scenarios < 5
        score -= 15 if (@draft_plan.our_bans&.size || 0) < 3
        score -= 10 if @draft_plan.comfort_picks_coverage < 50
        score -= 10 if @draft_plan.patch_version.blank?

        [score, 0].max
      end
    end
  end
end
