class Api::V1::VodTimestampsController < Api::V1::BaseController
  before_action :set_vod_review, only: [:index, :create]
  before_action :set_vod_timestamp, only: [:update, :destroy]

  def index
    authorize @vod_review, :show?
    timestamps = @vod_review.vod_timestamps
                 .includes(:target_player, :created_by)
                 .order(:timestamp_seconds)

    # Apply filters
    timestamps = timestamps.where(category: params[:category]) if params[:category].present?
    timestamps = timestamps.where(importance: params[:importance]) if params[:importance].present?
    timestamps = timestamps.where(target_player_id: params[:player_id]) if params[:player_id].present?

    render_success({
      timestamps: VodTimestampSerializer.render_as_hash(timestamps)
    })
  end

  def create
    authorize @vod_review, :update?
    timestamp = @vod_review.vod_timestamps.new(vod_timestamp_params)
    timestamp.created_by = current_user

    if timestamp.save
      log_user_action(
        action: 'create',
        entity_type: 'VodTimestamp',
        entity_id: timestamp.id,
        new_values: timestamp.attributes
      )

      render_created({
        timestamp: VodTimestampSerializer.render_as_hash(timestamp)
      }, message: 'Timestamp added successfully')
    else
      render_error(
        message: 'Failed to create timestamp',
        code: 'VALIDATION_ERROR',
        status: :unprocessable_entity,
        details: timestamp.errors.as_json
      )
    end
  end

  def update
    authorize @timestamp.vod_review, :update?
    old_values = @timestamp.attributes.dup

    if @timestamp.update(vod_timestamp_params)
      log_user_action(
        action: 'update',
        entity_type: 'VodTimestamp',
        entity_id: @timestamp.id,
        old_values: old_values,
        new_values: @timestamp.attributes
      )

      render_updated({
        timestamp: VodTimestampSerializer.render_as_hash(@timestamp)
      })
    else
      render_error(
        message: 'Failed to update timestamp',
        code: 'VALIDATION_ERROR',
        status: :unprocessable_entity,
        details: @timestamp.errors.as_json
      )
    end
  end

  def destroy
    authorize @timestamp.vod_review, :update?
    if @timestamp.destroy
      log_user_action(
        action: 'delete',
        entity_type: 'VodTimestamp',
        entity_id: @timestamp.id,
        old_values: @timestamp.attributes
      )

      render_deleted(message: 'Timestamp deleted successfully')
    else
      render_error(
        message: 'Failed to delete timestamp',
        code: 'DELETE_ERROR',
        status: :unprocessable_entity
      )
    end
  end

  private

  def set_vod_review
    @vod_review = organization_scoped(VodReview).find(params[:vod_review_id])
  end

  def set_vod_timestamp
    @timestamp = VodTimestamp.joins(:vod_review)
                             .where(vod_reviews: { organization: current_organization })
                             .find(params[:id])
  end

  def vod_timestamp_params
    params.require(:vod_timestamp).permit(
      :timestamp_seconds, :category, :importance,
      :title, :description, :target_type, :target_player_id
    )
  end
end
