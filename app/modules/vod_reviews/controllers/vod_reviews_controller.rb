# frozen_string_literal: true

module VodReviews
  module Controllers
    class VodReviewsController < Api::V1::BaseController
      before_action :set_vod_review, only: %i[show update destroy]

      def index
        authorize VodReview
        vod_reviews = organization_scoped(VodReview).includes(:match, :reviewer)

        vod_reviews = vod_reviews.where(status: params[:status]) if params[:status].present?

        vod_reviews = vod_reviews.where(match_id: params[:match_id]) if params[:match_id].present?

        vod_reviews = vod_reviews.where(reviewer_id: params[:reviewer_id]) if params[:reviewer_id].present?

        if params[:search].present?
          search_term = "%#{params[:search]}%"
          vod_reviews = vod_reviews.where('title ILIKE ?', search_term)
        end

        # Whitelist for sort parameters to prevent SQL injection
        allowed_sort_fields = %w[created_at updated_at title status reviewed_at]
        allowed_sort_orders = %w[asc desc]

        sort_by = allowed_sort_fields.include?(params[:sort_by]) ? params[:sort_by] : 'created_at'
        sort_order = allowed_sort_orders.include?(params[:sort_order]&.downcase) ? params[:sort_order].downcase : 'desc'
        vod_reviews = vod_reviews.order(sort_by => sort_order)

        result = paginate(vod_reviews)

        render_success({
                         vod_reviews: VodReviewSerializer.render_as_hash(result[:data], include_timestamps_count: true),
                         pagination: result[:pagination]
                       })
      end

      def show
        authorize @vod_review
        vod_review_data = VodReviewSerializer.render_as_hash(@vod_review)
        timestamps = VodTimestampSerializer.render_as_hash(
          @vod_review.vod_timestamps.includes(:target_player, :created_by).order(:timestamp_seconds)
        )

        render_success({
                         vod_review: vod_review_data,
                         timestamps: timestamps
                       })
      end

      def create
        authorize VodReview
        vod_review = organization_scoped(VodReview).new(vod_review_params)
        vod_review.organization = current_organization
        vod_review.reviewer = current_user

        if vod_review.save
          log_user_action(
            action: 'create',
            entity_type: 'VodReview',
            entity_id: vod_review.id,
            new_values: vod_review.attributes
          )

          render_created({
                           vod_review: VodReviewSerializer.render_as_hash(vod_review)
                         }, message: 'VOD review created successfully')
        else
          render_error(
            message: 'Failed to create VOD review',
            code: 'VALIDATION_ERROR',
            status: :unprocessable_entity,
            details: vod_review.errors.as_json
          )
        end
      end

      def update
        authorize @vod_review
        old_values = @vod_review.attributes.dup

        if @vod_review.update(vod_review_params)
          log_user_action(
            action: 'update',
            entity_type: 'VodReview',
            entity_id: @vod_review.id,
            old_values: old_values,
            new_values: @vod_review.attributes
          )

          render_updated({
                           vod_review: VodReviewSerializer.render_as_hash(@vod_review)
                         })
        else
          render_error(
            message: 'Failed to update VOD review',
            code: 'VALIDATION_ERROR',
            status: :unprocessable_entity,
            details: @vod_review.errors.as_json
          )
        end
      end

      def destroy
        authorize @vod_review
        if @vod_review.destroy
          log_user_action(
            action: 'delete',
            entity_type: 'VodReview',
            entity_id: @vod_review.id,
            old_values: @vod_review.attributes
          )

          render_deleted(message: 'VOD review deleted successfully')
        else
          render_error(
            message: 'Failed to delete VOD review',
            code: 'DELETE_ERROR',
            status: :unprocessable_entity
          )
        end
      end

      private

      def set_vod_review
        @vod_review = organization_scoped(VodReview).find(params[:id])
      end

      def vod_review_params
        params.require(:vod_review).permit(
          :title, :description, :review_type, :review_date,
          :video_url, :thumbnail_url, :duration,
          :status, :is_public, :match_id,
          tags: [], shared_with_players: []
        )
      end
    end
  end
end
