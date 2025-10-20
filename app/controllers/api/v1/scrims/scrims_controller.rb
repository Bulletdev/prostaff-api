module Api
  module V1
    module Scrims
      class ScrimsController < Api::V1::BaseController
        include TierAuthorization

        before_action :set_scrim, only: [:show, :update, :destroy, :add_game]

    # GET /api/v1/scrims
    def index
      scrims = current_organization.scrims
                                   .includes(:opponent_team, :match)
                                   .order(scheduled_at: :desc)

      # Filters
      scrims = scrims.by_type(params[:scrim_type]) if params[:scrim_type].present?
      scrims = scrims.by_focus_area(params[:focus_area]) if params[:focus_area].present?
      scrims = scrims.where(opponent_team_id: params[:opponent_team_id]) if params[:opponent_team_id].present?

      # Status filter
      case params[:status]
      when 'upcoming'
        scrims = scrims.upcoming
      when 'past'
        scrims = scrims.past
      when 'completed'
        scrims = scrims.completed
      when 'in_progress'
        scrims = scrims.in_progress
      end

      # Pagination
      page = params[:page] || 1
      per_page = params[:per_page] || 20

      scrims = scrims.page(page).per(per_page)

      render json: {
        data: {
          scrims: scrims.map { |scrim| ScrimSerializer.new(scrim).as_json },
          meta: pagination_meta(scrims)
        }
      }
    end

    # GET /api/v1/scrims/calendar
    def calendar
      start_date = params[:start_date]&.to_date || Date.current.beginning_of_month
      end_date = params[:end_date]&.to_date || Date.current.end_of_month

      scrims = current_organization.scrims
                                   .includes(:opponent_team)
                                   .where(scheduled_at: start_date..end_date)
                                   .order(scheduled_at: :asc)

      render json: {
        data: {
          scrims: scrims.map { |scrim| ScrimSerializer.new(scrim, calendar_view: true).as_json },
          start_date: start_date,
          end_date: end_date
        }
      }
    end

    # GET /api/v1/scrims/analytics
    def analytics
      service = ::Scrims::Services::ScrimAnalyticsService.new(current_organization)
      date_range = (params[:days]&.to_i || 30).days

      render json: {
        overall_stats: service.overall_stats(date_range: date_range),
        by_opponent: service.stats_by_opponent,
        by_focus_area: service.stats_by_focus_area,
        success_patterns: service.success_patterns,
        improvement_trends: service.improvement_trends
      }
    end

    # GET /api/v1/scrims/:id
    def show
      render json: { data: ScrimSerializer.new(@scrim, detailed: true).as_json }
    end

    # POST /api/v1/scrims
    def create
      # Check scrim creation limit
      unless current_organization.can_create_scrim?
        return render json: {
          error: 'Scrim Limit Reached',
          message: 'You have reached your monthly scrim limit. Upgrade to create more scrims.'
        }, status: :forbidden
      end

      scrim = current_organization.scrims.new(scrim_params)

      if scrim.save
        render json: { data: ScrimSerializer.new(scrim).as_json }, status: :created
      else
        render json: { errors: scrim.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH /api/v1/scrims/:id
    def update
      if @scrim.update(scrim_params)
        render json: { data: ScrimSerializer.new(@scrim).as_json }
      else
        render json: { errors: @scrim.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /api/v1/scrims/:id
    def destroy
      @scrim.destroy
      head :no_content
    end

    # POST /api/v1/scrims/:id/add_game
    def add_game
      victory = params[:victory]
      duration = params[:duration]
      notes = params[:notes]

      if @scrim.add_game_result(victory: victory, duration: duration, notes: notes)
        # Update opponent team stats if present
        if @scrim.opponent_team.present?
          @scrim.opponent_team.update_scrim_stats!(victory: victory)
        end

        render json: { data: ScrimSerializer.new(@scrim.reload).as_json }
      else
        render json: { errors: @scrim.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def set_scrim
      @scrim = current_organization.scrims.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Scrim not found' }, status: :not_found
    end

    def scrim_params
      params.require(:scrim).permit(
        :opponent_team_id,
        :match_id,
        :scheduled_at,
        :scrim_type,
        :focus_area,
        :pre_game_notes,
        :post_game_notes,
        :is_confidential,
        :visibility,
        :games_planned,
        :games_completed,
        game_results: [],
        objectives: {},
        outcomes: {}
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
  end
end
