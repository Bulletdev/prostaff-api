# frozen_string_literal: true

module Tournaments
  module Controllers
    # Enrollment management for a tournament.
    #
    # GET    /api/v1/tournaments/:tournament_id/teams              — list teams
    # POST   /api/v1/tournaments/:tournament_id/teams              — enroll org
    # PATCH  /api/v1/tournaments/:tournament_id/teams/:id/approve  — admin approve + roster lock
    # PATCH  /api/v1/tournaments/:tournament_id/teams/:id/reject   — admin reject
    # DELETE /api/v1/tournaments/:tournament_id/teams/:id          — withdraw (own team)
    class TournamentTeamsController < Api::V1::BaseController
      skip_before_action :authenticate_request!, only: %i[index]

      before_action :set_tournament
      before_action :set_team, only: %i[destroy approve reject]
      before_action :require_admin!, only: %i[approve reject]

      # GET /api/v1/tournaments/:tournament_id/teams
      def index
        teams = @tournament.tournament_teams.includes(:organization, :tournament_roster_snapshots)
        render_success(teams.map { |t| TournamentTeamSerializer.new(t, with_roster: true).as_json })
      end

      # POST /api/v1/tournaments/:tournament_id/teams
      def create
        unless @tournament.registration_open?
          return render_error(
            message: 'Registration is not open for this tournament',
            code: 'REGISTRATION_CLOSED',
            status: :unprocessable_entity
          )
        end

        unless @tournament.slots_available?
          return render_error(
            message: "Tournament is full (#{@tournament.max_teams} teams)",
            code: 'TOURNAMENT_FULL',
            status: :unprocessable_entity
          )
        end

        if @tournament.tournament_teams.exists?(organization: current_organization)
          return render_error(
            message: 'Your organization is already enrolled',
            code: 'ALREADY_ENROLLED',
            status: :unprocessable_entity
          )
        end

        team = TournamentTeam.new(
          tournament: @tournament,
          organization: current_organization,
          team_name: enrollment_params[:team_name] || current_organization.name,
          team_tag: enrollment_params[:team_tag]  || current_organization.team_tag,
          logo_url: enrollment_params[:logo_url]  || current_organization.logo_url
        )

        if team.save
          render_created(TournamentTeamSerializer.new(team).as_json)
        else
          render_error(
            message: team.errors.full_messages.join(', '),
            code: 'VALIDATION_ERROR',
            status: :unprocessable_entity
          )
        end
      end

      # PATCH /api/v1/tournaments/:tournament_id/teams/:id/approve
      def approve
        if @team.approved?
          return render_error(message: 'Team is already approved', code: 'ALREADY_APPROVED',
                              status: :unprocessable_entity)
        end

        ActiveRecord::Base.transaction do
          @team.approve!
          lock_roster!(@team)
        end

        render_success(TournamentTeamSerializer.new(@team, with_roster: true).as_json)
      end

      # PATCH /api/v1/tournaments/:tournament_id/teams/:id/reject
      def reject
        if @team.rejected?
          return render_error(message: 'Team is already rejected', code: 'ALREADY_REJECTED',
                              status: :unprocessable_entity)
        end

        @team.reject!
        render_success(TournamentTeamSerializer.new(@team).as_json)
      end

      # DELETE /api/v1/tournaments/:tournament_id/teams/:id
      def destroy
        unless @team.organization_id == current_organization.id || current_user&.admin_or_owner?
          return render_error(message: 'Forbidden', code: 'FORBIDDEN', status: :forbidden)
        end

        if @tournament.bracket_generated?
          return render_error(
            message: 'Cannot withdraw after bracket has been generated',
            code: 'BRACKET_LOCKED',
            status: :unprocessable_entity
          )
        end

        @team.withdraw!
        render_success({ withdrawn: true })
      end

      private

      def set_tournament
        @tournament = Tournament.find_by(id: params[:tournament_id])
        render_error(message: 'Tournament not found', code: 'NOT_FOUND', status: :not_found) unless @tournament
      end

      def set_team
        @team = @tournament.tournament_teams.find_by(id: params[:id])
        render_error(message: 'Team not found', code: 'NOT_FOUND', status: :not_found) unless @team
      end

      def require_admin!
        return if current_user&.admin_or_owner?

        render_error(message: 'Admin access required', code: 'FORBIDDEN', status: :forbidden)
      end

      # Roster Lock: snapshot all active players from the org at approval time.
      # This record is immutable — never updated after creation.
      def lock_roster!(team)
        org = team.organization
        players = org.players.where(status: %w[active rostered]).order(:role, :jersey_number)

        players.each_with_index do |player, idx|
          position = idx < 5 ? 'starter' : 'substitute'
          TournamentRosterSnapshot.create!(
            tournament_team: team,
            player: player,
            summoner_name: player.summoner_name,
            role: player.role,
            position: position,
            locked_at: Time.current
          )
        end
      end

      def enrollment_params
        params.permit(:team_name, :team_tag, :logo_url)
      end
    end
  end
end
