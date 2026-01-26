# frozen_string_literal: true

module Api
  module V1
    module Scrims
      # OpponentTeams Controller
      #
      # Manages opponent team records which are shared across organizations.
      # Security note: Update and delete operations are restricted to organizations
      # that have used this opponent team in scrims.
      #
      class OpponentTeamsController < Api::V1::BaseController
        include TierAuthorization
        include Paginatable

        before_action :set_opponent_team, only: %i[show update destroy scrim_history]
        before_action :verify_team_usage!, only: %i[update destroy]

        # GET /api/v1/scrims/opponent_teams
        def index
          teams = OpponentTeam.all.order(:name)

          # Filters
          teams = teams.by_region(params[:region]) if params[:region].present?
          teams = teams.by_tier(params[:tier]) if params[:tier].present?
          teams = teams.by_league(params[:league]) if params[:league].present?
          teams = teams.with_scrims if params[:with_scrims] == 'true'

          # Search
          if params[:search].present?
            search_term = ActiveRecord::Base.sanitize_sql_like(params[:search])
            teams = teams.where('name ILIKE ? OR tag ILIKE ?', "%#{search_term}%", "%#{search_term}%")
          end

          # Pagination
          page = params[:page] || 1
          per_page = params[:per_page] || 20

          teams = teams.page(page).per(per_page)

          render json: {
            data: {
              opponent_teams: teams.map { |team| ScrimOpponentTeamSerializer.new(team).as_json },
              meta: pagination_meta(teams)
            }
          }
        end

        # GET /api/v1/scrims/opponent_teams/:id
        def show
          render json: { data: ScrimOpponentTeamSerializer.new(@opponent_team, detailed: true).as_json }
        end

        # GET /api/v1/scrims/opponent_teams/:id/scrim_history
        def scrim_history
          scrims = current_organization.scrims
                                       .where(opponent_team_id: @opponent_team.id)
                                       .includes(:match)
                                       .order(scheduled_at: :desc)

          service = Scrims::ScrimAnalyticsService.new(current_organization)
          opponent_stats = service.opponent_performance(@opponent_team.id)

          render json: {
            data: {
              opponent_team: ScrimOpponentTeamSerializer.new(@opponent_team).as_json,
              scrims: scrims.map { |scrim| ScrimSerializer.new(scrim).as_json },
              stats: opponent_stats
            }
          }
        end

        # POST /api/v1/scrims/opponent_teams
        def create
          team = OpponentTeam.new(opponent_team_params)

          if team.save
            render json: { data: ScrimOpponentTeamSerializer.new(team).as_json }, status: :created
          else
            render json: { errors: team.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # PATCH /api/v1/scrims/opponent_teams/:id
        def update
          if @opponent_team.update(opponent_team_params)
            render json: { data: ScrimOpponentTeamSerializer.new(@opponent_team).as_json }
          else
            render json: { errors: @opponent_team.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/scrims/opponent_teams/:id
        def destroy
          # Check if team has scrims from other organizations before deleting
          other_org_scrims = @opponent_team.scrims.where.not(organization_id: current_organization.id).exists?

          if other_org_scrims
            return render json: {
              error: 'Cannot delete opponent team that is used by other organizations'
            }, status: :unprocessable_entity
          end

          @opponent_team.destroy
          head :no_content
        end

        private

        # Finds opponent team by ID
        # Security Note: OpponentTeam is a shared resource across organizations.
        # Access control is enforced via verify_team_usage! before_action for
        # sensitive operations (update/destroy). This ensures organizations can
        # only modify teams they have scrims with.
        # Read operations (index/show) are allowed for all teams to enable discovery.
        #
        def set_opponent_team
          id = Integer(params[:id], exception: false)
          return render json: { error: 'Opponent team not found' }, status: :not_found unless id

          @opponent_team = OpponentTeam.find_by(id: id)
          return render json: { error: 'Opponent team not found' }, status: :not_found unless @opponent_team
        end

        # Verifies that current organization has used this opponent team
        # Prevents organizations from modifying/deleting teams they haven't interacted with
        def verify_team_usage!
          has_scrims = current_organization.scrims.exists?(opponent_team_id: @opponent_team.id)

          return if has_scrims

          render json: {
            error: 'You cannot modify this opponent team. Your organization has not played against them.'
          }, status: :forbidden
        end

        def opponent_team_params
          params.require(:opponent_team).permit(
            :name,
            :tag,
            :region,
            :tier,
            :league,
            :logo_url,
            :playstyle_notes,
            :contact_email,
            :discord_server,
            known_players: [],
            strengths: [],
            weaknesses: [],
            recent_performance: {},
            preferred_champions: {}
          )
        end
      end
    end
  end
end
