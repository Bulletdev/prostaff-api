# frozen_string_literal: true

module Players
  # Service to handle player roster management:
  # - Removing players from roster
  # - Moving players to scouting pool as free agents
  # - Hiring players from scouting pool
  class RosterManagementService
    attr_reader :player, :organization, :current_user

    def initialize(player:, organization:, current_user: nil)
      @player = player
      @organization = organization
      @current_user = current_user
    end

    # Remove player from current roster and move to free agent pool
    # @param reason [String] Reason for removal (e.g., "Contract ended", "Released", "Mutual agreement")
    # @return [Hash] Result with success status and scouting target if created
    def remove_from_roster(reason:)
      ActiveRecord::Base.transaction do
        previous_org_id = player.organization_id
        previous_org_name = player.organization.name

        # Soft delete the player (removes from roster but keeps in database)
        player.soft_delete!(
          reason: reason,
          previous_org_id: previous_org_id
        )

        # Create scouting target entry for this free agent
        scouting_target = create_scouting_target_from_player(
          previous_org_name: previous_org_name,
          removal_reason: reason
        )

        # Log the action
        log_roster_removal(previous_org_id, reason)

        {
          success: true,
          player: player,
          scouting_target: scouting_target,
          message: "#{player.summoner_name} removed from roster and added to free agent pool"
        }
      end
    rescue StandardError => e
      {
        success: false,
        error: e.message,
        code: 'ROSTER_REMOVAL_ERROR'
      }
    end

    # Hire a player from the scouting pool (free agent or from another team)
    # @param scouting_target [ScoutingTarget] The scouting target to hire
    # @param contract_start [Date] Contract start date
    # @param contract_end [Date] Contract end date
    # @param salary [Decimal] Player salary (optional)
    # @param jersey_number [Integer] Jersey number (optional)
    # @return [Hash] Result with success status and player
    def self.hire_from_scouting(scouting_target:, organization:, contract_start:, contract_end:, salary: nil, jersey_number: nil, current_user: nil)
      ActiveRecord::Base.transaction do
        # Check if this is a free agent or needs to be restored
        player = find_or_restore_player(scouting_target, organization)

        # Update player with new contract details
        player.update!(
          organization: organization,
          status: 'active',
          contract_start_date: contract_start,
          contract_end_date: contract_end,
          salary: salary,
          jersey_number: jersey_number,
          deleted_at: nil,
          removed_reason: nil,
          previous_organization_id: nil
        )

        # Update watchlist status to signed
        watchlist = scouting_target.scouting_watchlists.find_by(organization: organization)
        watchlist&.update!(status: 'signed')

        # Log the action
        log_roster_addition(player, scouting_target, current_user)

        {
          success: true,
          player: player,
          message: "#{player.summoner_name} successfully added to roster"
        }
      end
    rescue StandardError => e
      {
        success: false,
        error: e.message,
        code: 'ROSTER_HIRE_ERROR'
      }
    end

    # Get all free agents (players without a team)
    # @return [ActiveRecord::Relation] Players marked as removed/free agents
    def self.free_agents
      Player.with_deleted
            .where(status: 'removed')
            .where.not(deleted_at: nil)
            .includes(:organization)
            .order(deleted_at: :desc)
    end

    private

    # Create a scouting target from removed player
    # Now creates/updates GLOBAL target + watchlist entry for current org
    def create_scouting_target_from_player(previous_org_name:, removal_reason:)
      # Find or create global scouting target
      target = ScoutingTarget.find_or_initialize_by(riot_puuid: player.riot_puuid) if player.riot_puuid.present?
      target ||= ScoutingTarget.new

      # Update global player data
      target.assign_attributes(
        summoner_name: player.summoner_name,
        region: normalize_region(player.region),
        riot_puuid: player.riot_puuid,
        role: player.role,
        current_tier: player.solo_queue_tier,
        current_rank: player.solo_queue_rank,
        current_lp: player.solo_queue_lp,
        champion_pool: player.champion_pool,
        playstyle: extract_playstyle_from_notes(player.notes),
        twitter_handle: player.twitter_handle,
        status: 'free_agent',
        real_name: player.real_name,
        avatar_url: player.avatar_url
      )

      target.save!

      # Create or update watchlist entry for this organization
      watchlist = target.scouting_watchlists.find_or_initialize_by(organization: organization)
      watchlist.assign_attributes(
        added_by: current_user,
        priority: 'medium',
        status: 'watching',
        notes: build_free_agent_notes(previous_org_name, removal_reason, watchlist.notes)
      )
      watchlist.save!

      target
    end

    # Build notes for free agent scouting target
    def build_free_agent_notes(previous_org_name, removal_reason, existing_notes = nil)
      notes = []
      notes << existing_notes if existing_notes.present?
      notes << "**Free Agent** - Previously with #{previous_org_name}"
      notes << "Removal reason: #{removal_reason}" if removal_reason.present?
      notes << "Available since: #{Date.current.strftime('%Y-%m-%d')}"
      notes << "\n--- Original Player Notes ---\n#{player.notes}" if player.notes.present?
      notes.join("\n\n")
    end

    # Extract playstyle from player notes
    def extract_playstyle_from_notes(notes)
      return nil if notes.blank?

      # Try to find playstyle keywords
      playstyles = %w[aggressive passive calculated mechanical macro supportive carry playmaker]
      playstyles.find { |style| notes.downcase.include?(style) }
    end

    # Normalize region format from Riot API format (br1, na1) to internal format (BR, NA)
    # @param region [String, nil] Region from player (can be nil, lowercase with numbers, or uppercase)
    # @return [String] Normalized region code (e.g., "BR", "NA", "EUW")
    def normalize_region(region)
      return 'BR' if region.blank?

      # Remove numbers and convert to uppercase
      normalized = region.to_s.gsub(/\d+/, '').upcase

      # Validate against allowed regions
      if Constants::REGIONS.include?(normalized)
        normalized
      else
        # Default to BR if unknown region
        'BR'
      end
    end

    # Find existing soft-deleted player or prepare for new player creation
    def self.find_or_restore_player(scouting_target, organization)
      # Try to find soft-deleted player by PUUID
      if scouting_target.riot_puuid.present?
        player = Player.with_deleted.find_by(riot_puuid: scouting_target.riot_puuid)
        return player if player
      end

      # If player doesn't exist, create new one from scouting target
      Player.with_deleted.create!(
        organization: organization,
        summoner_name: scouting_target.summoner_name,
        role: scouting_target.role,
        region: scouting_target.region,
        riot_puuid: scouting_target.riot_puuid,
        solo_queue_tier: scouting_target.current_tier,
        solo_queue_rank: scouting_target.current_rank,
        solo_queue_lp: scouting_target.current_lp,
        champion_pool: scouting_target.champion_pool,
        twitter_handle: scouting_target.twitter_handle,
        notes: "Hired from scouting pool\n\n#{scouting_target.notes}",
        status: 'active'
      )
    end

    # Log roster removal action
    def log_roster_removal(previous_org_id, reason)
      return unless current_user

      AuditLog.create!(
        organization_id: previous_org_id,
        user_id: current_user.id,
        action: 'roster_removal',
        entity_type: 'Player',
        entity_id: player.id,
        old_values: {
          status: 'active',
          organization_id: previous_org_id
        },
        new_values: {
          status: 'removed',
          deleted_at: player.deleted_at,
          removed_reason: reason
        }
      )
    end

    # Log roster addition action
    def self.log_roster_addition(player, scouting_target, current_user)
      return unless current_user

      AuditLog.create!(
        organization_id: player.organization_id,
        user_id: current_user.id,
        action: 'roster_addition',
        entity_type: 'Player',
        entity_id: player.id,
        old_values: {
          status: player.status_was,
          organization_id: player.previous_organization_id
        },
        new_values: {
          status: player.status,
          organization_id: player.organization_id,
          contract_start_date: player.contract_start_date,
          contract_end_date: player.contract_end_date,
          source: 'scouting_target',
          scouting_target_id: scouting_target.id
        }
      )
    end
  end
end
