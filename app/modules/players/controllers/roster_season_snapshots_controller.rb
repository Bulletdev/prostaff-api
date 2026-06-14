# frozen_string_literal: true

module Players
  module Controllers
    # Controller for reading seasonal roster snapshots
    #
    # Returns point-in-time records of which players were on the active roster
    # for the organization's competitive seasons/splits.
    #
    # @example List all snapshots
    #   GET /api/v1/rosters/season-snapshots
    #   Response: { data: { snapshots: [...] } }
    #
    # @example Filter by season
    #   GET /api/v1/rosters/season-snapshots?season=2026-split1
    #   Response: { data: { snapshots: [...] } }
    class RosterSeasonSnapshotsController < Api::V1::BaseController
      # GET /api/v1/rosters/season-snapshots
      #
      # @param [String] season Optional season filter (e.g. "2026-split1")
      # @return [JSON] List of snapshots with their player slots
      def index
        snapshots = current_organization.roster_season_snapshots
                                        .includes(roster_season_slots: :player)
                                        .recent
        snapshots = snapshots.for_season(params[:season]) if params[:season].present?
        render_success({ snapshots: snapshots.map { |s| serialize_snapshot(s) } })
      end

      private

      def serialize_snapshot(snapshot)
        {
          id: snapshot.id,
          season: snapshot.season,
          snapshot_date: snapshot.snapshot_date,
          notes: snapshot.notes,
          slots: snapshot.roster_season_slots.map { |slot| serialize_slot(slot) }
        }
      end

      def serialize_slot(slot)
        {
          id: slot.id,
          line: slot.line,
          role: slot.role,
          transfer_status: slot.transfer_status,
          player_id: slot.player_id,
          player_name: slot.player&.summoner_name
        }
      end
    end
  end
end
