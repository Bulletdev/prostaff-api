class Api::V1::Scouting::PlayersController < Api::V1::BaseController
  before_action :set_scouting_target, only: [:show, :update, :destroy, :sync]

  def index
    targets = organization_scoped(ScoutingTarget).includes(:added_by, :assigned_to)

    # Apply filters
    targets = targets.by_role(params[:role]) if params[:role].present?
    targets = targets.by_status(params[:status]) if params[:status].present?
    targets = targets.by_priority(params[:priority]) if params[:priority].present?
    targets = targets.by_region(params[:region]) if params[:region].present?

    # Special filters
    targets = targets.active if params[:active] == 'true'
    targets = targets.high_priority if params[:high_priority] == 'true'
    targets = targets.needs_review if params[:needs_review] == 'true'
    targets = targets.assigned_to_user(params[:assigned_to_id]) if params[:assigned_to_id].present?

    # Search
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      targets = targets.where('summoner_name ILIKE ? OR real_name ILIKE ?', search_term, search_term)
    end

    # Sorting
    sort_by = params[:sort_by] || 'created_at'
    sort_order = params[:sort_order] || 'desc'

    # Map 'rank' to actual column names
    if sort_by == 'rank'
      targets = targets.order("current_lp #{sort_order} NULLS LAST")
    elsif sort_by == 'winrate'
      targets = targets.order("performance_trend #{sort_order} NULLS LAST")
    else
      targets = targets.order("#{sort_by} #{sort_order}")
    end

    # Pagination
    result = paginate(targets)

    render_success({
      players: ScoutingTargetSerializer.render_as_hash(result[:data]),
      total: result[:pagination][:total_count],
      page: result[:pagination][:current_page],
      per_page: result[:pagination][:per_page],
      total_pages: result[:pagination][:total_pages]
    })
  end

  def show
    render_success({
      scouting_target: ScoutingTargetSerializer.render_as_hash(@target)
    })
  end

  def create
    target = organization_scoped(ScoutingTarget).new(scouting_target_params)
    target.organization = current_organization
    target.added_by = current_user

    if target.save
      log_user_action(
        action: 'create',
        entity_type: 'ScoutingTarget',
        entity_id: target.id,
        new_values: target.attributes
      )

      render_created({
        scouting_target: ScoutingTargetSerializer.render_as_hash(target)
      }, message: 'Scouting target added successfully')
    else
      render_error(
        message: 'Failed to add scouting target',
        code: 'VALIDATION_ERROR',
        status: :unprocessable_entity,
        details: target.errors.as_json
      )
    end
  end

  def update
    old_values = @target.attributes.dup

    if @target.update(scouting_target_params)
      log_user_action(
        action: 'update',
        entity_type: 'ScoutingTarget',
        entity_id: @target.id,
        old_values: old_values,
        new_values: @target.attributes
      )

      render_updated({
        scouting_target: ScoutingTargetSerializer.render_as_hash(@target)
      })
    else
      render_error(
        message: 'Failed to update scouting target',
        code: 'VALIDATION_ERROR',
        status: :unprocessable_entity,
        details: @target.errors.as_json
      )
    end
  end

  def destroy
    if @target.destroy
      log_user_action(
        action: 'delete',
        entity_type: 'ScoutingTarget',
        entity_id: @target.id,
        old_values: @target.attributes
      )

      render_deleted(message: 'Scouting target removed successfully')
    else
      render_error(
        message: 'Failed to remove scouting target',
        code: 'DELETE_ERROR',
        status: :unprocessable_entity
      )
    end
  end

  def sync
    # This will sync the scouting target with Riot API
    # Will be implemented when Riot API service is ready
    render_error(
      message: 'Sync functionality not yet implemented',
      code: 'NOT_IMPLEMENTED',
      status: :not_implemented
    )
  end

  private

  def set_scouting_target
    @target = organization_scoped(ScoutingTarget).find(params[:id])
  end

  def scouting_target_params
    params.require(:scouting_target).permit(
      :summoner_name, :real_name, :role, :region, :nationality,
      :age, :status, :priority, :current_team,
      :current_tier, :current_rank, :current_lp,
      :peak_tier, :peak_rank,
      :riot_puuid, :riot_summoner_id,
      :email, :phone, :discord_username, :twitter_handle,
      :scouting_notes, :contact_notes,
      :availability, :salary_expectations,
      :performance_trend, :assigned_to_id,
      champion_pool: []
    )
  end
end
