# frozen_string_literal: true

module Api
  module V1
    # Constants Controller
    #
    # Provides application-wide constant values and enumerations for frontend consumption.
    # Returns all valid options for dropdowns, filters, and validation including regions, tiers,
    # roles, statuses, and other enumerated values used throughout the application.
    #
    # @example GET /api/v1/constants
    #   {
    #     regions: { values: ['BR', 'NA', 'EUW'], names: { 'BR': 'Brazil' } },
    #     player: { roles: {...}, statuses: {...}, queue_ranks: [...] }
    #   }
    #
    # Main endpoints:
    # - GET index: Returns comprehensive constants for all application entities (public, no auth required)
    class ConstantsController < ApplicationController
      # GET /api/v1/constants
      # Public endpoint - no authentication required
      def index
        render json: {
          data: {
            regions: regions_data,
            organization: organization_data,
            user: user_data,
            player: player_data,
            match: match_data,
            scrim: scrim_data,
            competitive_match: competitive_match_data,
            opponent_team: opponent_team_data,
            schedule: schedule_data,
            team_goal: team_goal_data,
            vod_review: vod_review_data,
            vod_timestamp: vod_timestamp_data,
            scouting_target: scouting_target_data,
            champion_pool: champion_pool_data
          }
        }
      end

      private

      def regions_data
        {
          values: Constants::REGIONS,
          names: Constants::REGION_NAMES
        }
      end

      def organization_data
        {
          tiers: {
            values: Constants::Organization::TIERS,
            names: Constants::Organization::TIER_NAMES
          },
          subscription_plans: {
            values: Constants::Organization::SUBSCRIPTION_PLANS,
            names: Constants::Organization::SUBSCRIPTION_PLAN_NAMES
          },
          subscription_statuses: Constants::Organization::SUBSCRIPTION_STATUSES
        }
      end

      def user_data
        {
          roles: {
            values: Constants::User::ROLES,
            names: Constants::User::ROLE_NAMES
          }
        }
      end

      def player_data
        {
          roles: {
            values: Constants::Player::ROLES,
            names: Constants::Player::ROLE_NAMES
          },
          statuses: {
            values: Constants::Player::STATUSES,
            names: Constants::Player::STATUS_NAMES
          },
          queue_ranks: Constants::Player::QUEUE_RANKS,
          queue_tiers: Constants::Player::QUEUE_TIERS
        }
      end

      def match_data
        {
          types: {
            values: Constants::Match::TYPES,
            names: Constants::Match::TYPE_NAMES
          },
          sides: {
            values: Constants::Match::SIDES,
            names: Constants::Match::SIDE_NAMES
          }
        }
      end

      def scrim_data
        {
          types: {
            values: Constants::Scrim::TYPES,
            names: Constants::Scrim::TYPE_NAMES
          },
          focus_areas: {
            values: Constants::Scrim::FOCUS_AREAS,
            names: Constants::Scrim::FOCUS_AREA_NAMES
          },
          visibility_levels: {
            values: Constants::Scrim::VISIBILITY_LEVELS,
            names: Constants::Scrim::VISIBILITY_NAMES
          }
        }
      end

      def competitive_match_data
        {
          formats: {
            values: Constants::CompetitiveMatch::FORMATS,
            names: Constants::CompetitiveMatch::FORMAT_NAMES
          },
          sides: {
            values: Constants::CompetitiveMatch::SIDES,
            names: Constants::Match::SIDE_NAMES
          }
        }
      end

      def opponent_team_data
        {
          tiers: {
            values: Constants::OpponentTeam::TIERS,
            names: Constants::OpponentTeam::TIER_NAMES
          }
        }
      end

      def schedule_data
        {
          event_types: {
            values: Constants::Schedule::EVENT_TYPES,
            names: Constants::Schedule::EVENT_TYPE_NAMES
          },
          statuses: {
            values: Constants::Schedule::STATUSES,
            names: Constants::Schedule::STATUS_NAMES
          }
        }
      end

      def team_goal_data
        {
          categories: {
            values: Constants::TeamGoal::CATEGORIES,
            names: Constants::TeamGoal::CATEGORY_NAMES
          },
          metric_types: {
            values: Constants::TeamGoal::METRIC_TYPES,
            names: Constants::TeamGoal::METRIC_TYPE_NAMES
          },
          statuses: {
            values: Constants::TeamGoal::STATUSES,
            names: Constants::TeamGoal::STATUS_NAMES
          }
        }
      end

      def vod_review_data
        {
          types: {
            values: Constants::VodReview::TYPES,
            names: Constants::VodReview::TYPE_NAMES
          },
          statuses: {
            values: Constants::VodReview::STATUSES,
            names: Constants::VodReview::STATUS_NAMES
          }
        }
      end

      def vod_timestamp_data
        {
          categories: {
            values: Constants::VodTimestamp::CATEGORIES,
            names: Constants::VodTimestamp::CATEGORY_NAMES
          },
          importance_levels: {
            values: Constants::VodTimestamp::IMPORTANCE_LEVELS,
            names: Constants::VodTimestamp::IMPORTANCE_NAMES
          },
          target_types: {
            values: Constants::VodTimestamp::TARGET_TYPES,
            names: Constants::VodTimestamp::TARGET_TYPE_NAMES
          }
        }
      end

      def scouting_target_data
        {
          statuses: {
            values: Constants::ScoutingTarget::STATUSES,
            names: Constants::ScoutingTarget::STATUS_NAMES
          },
          priorities: {
            values: Constants::ScoutingTarget::PRIORITIES,
            names: Constants::ScoutingTarget::PRIORITY_NAMES
          }
        }
      end

      def champion_pool_data
        {
          mastery_levels: {
            values: Constants::ChampionPool::MASTERY_LEVELS.to_a,
            names: Constants::ChampionPool::MASTERY_LEVEL_NAMES
          },
          priority_levels: Constants::ChampionPool::PRIORITY_LEVELS.to_a
        }
      end
    end
  end
end
