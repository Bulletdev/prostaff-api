# frozen_string_literal: true

module VodReviews
  module Controllers
    # CRUD API for VOD review sessions, with filtering by status, match, and reviewer.
    class VodReviewsController < Api::V1::BaseController
      before_action :set_vod_review,
                    only: %i[show update destroy player analyze analyze_status import_suggestions]

      def index
        authorize VodReview
        vod_reviews = organization_scoped(VodReview).includes(:organization, :match, :reviewer, :vod_timestamps)

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

      # Returns the VOD review data optimized for the video player UI.
      # Includes all timestamps ordered chronologically.
      # This endpoint is intentionally not cached — timestamps change frequently.
      def player
        authorize @vod_review, :show?
        timestamps = @vod_review.vod_timestamps
                                .includes(:target_player, :created_by)
                                .order(:timestamp_seconds)
        latest_job = @vod_review.vod_analysis_jobs
                                .where(status: 'done')
                                .order(created_at: :desc)
                                .first
        render_success({
                         vod_review: VodReviewSerializer.render_as_hash(@vod_review),
                         timestamps: VodTimestampSerializer.render_as_hash(timestamps),
                         latest_analysis_job: latest_job ? { id: latest_job.id, status: latest_job.status } : nil
                       })
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

      # POST /api/v1/vod-reviews/:id/analyze
      # Enqueues a VideoAI analysis job for the given VOD review.
      #
      # @return [JSON] job_id and initial status ('pending')
      def analyze
        authorize @vod_review, :update?

        job = @vod_review.vod_analysis_jobs.create!(status: 'pending')
        AnalyzeVodJob.perform_later(job.id)

        render_created({ job_id: job.id, status: job.status }, message: 'Analysis queued')
      end

      # GET /api/v1/vod-reviews/:id/analyze/:job_id
      # Returns current status of an analysis job, polling VideoAI when in progress.
      #
      # @return [JSON] job status, progress, and suggested_timestamps when done
      def analyze_status
        authorize @vod_review, :show?

        job = @vod_review.vod_analysis_jobs.find(params[:job_id])
        sync_job_status(job) if job.in_progress? && job.external_job_id.present?

        render_success(build_status_payload(job))
      end

      # POST /api/v1/vod-reviews/:id/import_suggestions
      # Imports selected AI suggestions as real VodTimestamps.
      #
      # @param job_id [String] UUID of a done VodAnalysisJob
      # @param suggestion_ids [Array<String>] IDs of suggestions to import
      # @return [JSON] count of imported timestamps and their serialized data
      def import_suggestions
        authorize @vod_review, :update?

        job = @vod_review.vod_analysis_jobs.done.find(params.require(:job_id))
        suggestion_ids = params.require(:suggestion_ids)

        created = import_from_job(job, suggestion_ids)

        render_created({
                         imported_count: created.size,
                         timestamps: VodTimestampSerializer.render_as_hash(created)
                       }, message: "#{created.size} timestamp(s) imported")
      end

      private

      def set_vod_review
        # Try to find by HashID first, then fall back to UUID
        id_param = params[:id]

        @vod_review = if id_param.match?(/\A[a-zA-Z0-9]{6,12}\z/)
                        # Looks like a HashID (Base62, 6-12 chars)
                        VodReview.find_by_hashid(id_param)
                      else
                        # Looks like a UUID or numeric ID
                        organization_scoped(VodReview).includes(:organization, :match, :reviewer).find_by(id: id_param)
                      end

        # If not found, raise 404
        raise ActiveRecord::RecordNotFound, "Couldn't find VodReview with id=#{id_param}" if @vod_review.nil?
      end

      def vod_review_params
        params.require(:vod_review).permit(
          :title, :description, :review_type, :review_date,
          :video_url, :thumbnail_url, :duration,
          :status, :is_public, :match_id,
          tags: [], shared_with_players: [],
          video_urls: [], video_sync_offsets: [], video_labels: []
        )
      end

      def sync_job_status(job)
        remote = VideoAiClient.get_job(job.external_job_id)
        updates = build_remote_updates(remote, job)
        job.update!(updates)
      rescue VideoAiClient::Error
        nil
      end

      def build_remote_updates(remote, job)
        updates = { status: remote[:status], progress: remote[:progress].to_i }
        if remote[:status] == 'done' && remote[:suggested_timestamps].present?
          updates[:suggested_timestamps] = tag_suggestions(remote[:suggested_timestamps], job.id)
        elsif remote[:status] == 'failed'
          updates[:error_message] = remote[:error_message]
        end
        updates
      end

      def tag_suggestions(suggestions, job_id)
        suggestions.map.with_index { |s, i| s.merge('id' => "#{job_id}-#{i}") }
      end

      def build_status_payload(job)
        {
          job_id: job.id,
          status: job.status,
          progress: job.progress,
          suggested_timestamps: job.done? ? job.suggested_timestamps : nil,
          error_message: job.failed? ? job.error_message : nil
        }
      end

      def import_from_job(job, suggestion_ids)
        timestamps_to_import = job.suggested_timestamps.select do |s|
          suggestion_ids.include?(s['id'])
        end

        timestamps_to_import.map do |suggestion|
          @vod_review.vod_timestamps.create!(
            timestamp_seconds: suggestion['start_seconds'].to_f.round,
            title: suggestion['reason'].gsub('+', ' e ').humanize,
            importance: confidence_to_importance(suggestion['confidence']),
            category: nil,
            created_by: current_user
          )
        end
      end

      def confidence_to_importance(confidence)
        conf = confidence.to_f
        return 'critical' if conf >= 0.9
        return 'high' if conf >= 0.7
        return 'normal' if conf >= 0.5

        'low'
      end
    end
  end
end
