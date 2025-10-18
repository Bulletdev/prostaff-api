module Scrims
  class OpponentTeamsController < ApplicationController
    include TierAuthorization

    before_action :set_opponent_team, only: [:show, :update, :destroy, :scrim_history]

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
        teams = teams.where('name ILIKE ? OR tag ILIKE ?', "%#{params[:search]}%", "%#{params[:search]}%")
      end

      # Pagination
      page = params[:page] || 1
      per_page = params[:per_page] || 20

      teams = teams.page(page).per(per_page)

      render json: {
        opponent_teams: teams.map { |team| OpponentTeamSerializer.new(team).as_json },
        meta: pagination_meta(teams)
      }
    end

    # GET /api/v1/scrims/opponent_teams/:id
    def show
      render json: OpponentTeamSerializer.new(@opponent_team, detailed: true).as_json
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
        opponent_team: OpponentTeamSerializer.new(@opponent_team).as_json,
        scrims: scrims.map { |scrim| ScrimSerializer.new(scrim).as_json },
        stats: opponent_stats
      }
    end

    # POST /api/v1/scrims/opponent_teams
    def create
      team = OpponentTeam.new(opponent_team_params)

      if team.save
        render json: OpponentTeamSerializer.new(team).as_json, status: :created
      else
        render json: { errors: team.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH /api/v1/scrims/opponent_teams/:id
    def update
      if @opponent_team.update(opponent_team_params)
        render json: OpponentTeamSerializer.new(@opponent_team).as_json
      else
        render json: { errors: @opponent_team.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /api/v1/scrims/opponent_teams/:id
    def destroy
      @opponent_team.destroy
      head :no_content
    end

    private

    def set_opponent_team
      @opponent_team = OpponentTeam.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Opponent team not found' }, status: :not_found
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

    def pagination_meta(collection)
      {
        current_page: collection.current_page,
        total_pages: collection.total_pages,
        total_count: collection.total_count,
        per_page: collection.limit_value
      }
    end
  end
end
