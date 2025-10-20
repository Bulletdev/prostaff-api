module Api
  module V1
    module Competitive
      class DraftComparisonController < Api::V1::BaseController
        # POST /api/v1/competitive/draft-comparison
        # Compare user's draft with professional meta
        def compare
          validate_draft_params!

          comparison = ::Competitive::Services::DraftComparatorService.compare_draft(
            our_picks: params[:our_picks],
            opponent_picks: params[:opponent_picks] || [],
            our_bans: params[:our_bans] || [],
            opponent_bans: params[:opponent_bans] || [],
            patch: params[:patch],
            organization: current_organization
          )

          render json: {
            message: 'Draft comparison completed successfully',
            data: ::Competitive::Serializers::DraftComparisonSerializer.render_as_hash(comparison)
          }
        rescue ArgumentError => e
          render json: {
            error: {
              code: 'INVALID_PARAMS',
              message: e.message
            }
          }, status: :unprocessable_entity
        rescue StandardError => e
          Rails.logger.error "[DraftComparison] Error: #{e.message}\n#{e.backtrace.join("\n")}"
          render json: {
            error: {
              code: 'COMPARISON_ERROR',
              message: 'Failed to compare draft',
              details: e.message
            }
          }, status: :internal_server_error
        end

        # GET /api/v1/competitive/meta/:role
        # Get meta picks and bans for a specific role
        def meta_by_role
          role = params[:role]
          patch = params[:patch]

          raise ArgumentError, 'Role is required' if role.blank?

          meta_data = ::Competitive::Services::DraftComparatorService.new.meta_analysis(
            role: role,
            patch: patch
          )

          render json: {
            message: "Meta analysis for #{role} retrieved successfully",
            data: meta_data
          }
        rescue ArgumentError => e
          render json: {
            error: {
              code: 'INVALID_PARAMS',
              message: e.message
            }
          }, status: :unprocessable_entity
        end

        # GET /api/v1/competitive/composition-winrate
        # Calculate winrate of a specific composition
        def composition_winrate
          champions = params[:champions]
          patch = params[:patch]

          raise ArgumentError, 'Champions array is required' if champions.blank?

          winrate = ::Competitive::Services::DraftComparatorService.new.composition_winrate(
            champions: champions,
            patch: patch
          )

          render json: {
            message: 'Composition winrate calculated successfully',
            data: {
              champions: champions,
              patch: patch,
              winrate: winrate,
              note: 'Based on professional matches in our database'
            }
          }
        rescue ArgumentError => e
          render json: {
            error: {
              code: 'INVALID_PARAMS',
              message: e.message
            }
          }, status: :unprocessable_entity
        end

        # GET /api/v1/competitive/counters
        # Suggest counters for an opponent pick
        def suggest_counters
          opponent_pick = params[:opponent_pick]
          role = params[:role]
          patch = params[:patch]

          raise ArgumentError, 'opponent_pick and role are required' if opponent_pick.blank? || role.blank?

          counters = ::Competitive::Services::DraftComparatorService.new.suggest_counters(
            opponent_pick: opponent_pick,
            role: role,
            patch: patch
          )

          render json: {
            message: 'Counter picks retrieved successfully',
            data: {
              opponent_pick: opponent_pick,
              role: role,
              patch: patch,
              suggested_counters: counters
            }
          }
        rescue ArgumentError => e
          render json: {
            error: {
              code: 'INVALID_PARAMS',
              message: e.message
            }
          }, status: :unprocessable_entity
        end

        private

        def validate_draft_params!
          raise ArgumentError, 'our_picks is required' if params[:our_picks].blank?
          raise ArgumentError, 'our_picks must be an array' unless params[:our_picks].is_a?(Array)
          raise ArgumentError, 'our_picks must contain 1-5 champions' unless params[:our_picks].size.between?(1, 5)
        end
      end
    end
  end
end
