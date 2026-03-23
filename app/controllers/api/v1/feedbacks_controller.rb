# frozen_string_literal: true

module Api
  module V1
    # Feedback API — users submit suggestions, reports, and upvote each other's feedback.
    #
    # GET  /api/v1/feedbacks          — public board (any authenticated user)
    # POST /api/v1/feedbacks          — create (any authenticated user)
    # POST /api/v1/feedbacks/:id/vote — toggle upvote (any authenticated user)
    class FeedbacksController < BaseController
      before_action :set_feedback, only: [:vote]

      # GET /api/v1/feedbacks
      def index
        authorize :feedback, :index?

        feedbacks = Feedback.recent.includes(:feedback_votes)
        feedbacks = feedbacks.by_category(params[:category]) if params[:category].present?
        feedbacks = feedbacks.where(status: params[:status])  if params[:status].present?

        result = paginate(feedbacks)
        items  = result[:data].map { |f| feedback_data(f, user: current_user) }

        render_success({ data: items, pagination: result[:pagination] })
      end

      # POST /api/v1/feedbacks
      def create
        feedback = Feedback.new(feedback_params)
        feedback.user         = current_user
        feedback.organization = current_organization

        if feedback.save
          render_created({ feedback: feedback_data(feedback, user: current_user) }, message: 'Feedback submitted successfully')
        else
          render_error(message: 'Invalid feedback', code: 'VALIDATION_ERROR', status: :unprocessable_entity, details: feedback.errors.as_json)
        end
      end

      # POST /api/v1/feedbacks/:id/vote
      def vote
        existing = @feedback.feedback_votes.find_by(user: current_user)

        if existing
          existing.destroy
          @feedback.decrement!(:votes_count)
          render_success({ votes_count: @feedback.votes_count, user_voted: false }, message: 'Vote removed')
        else
          @feedback.feedback_votes.create!(user: current_user)
          @feedback.increment!(:votes_count)
          render_success({ votes_count: @feedback.votes_count, user_voted: true }, message: 'Vote added')
        end
      end

      private

      def set_feedback
        @feedback = Feedback.find(params[:id])
      end

      def feedback_params
        params.require(:feedback).permit(:category, :title, :description, :rating)
      end

      def feedback_data(feedback, user: nil)
        voted = user ? feedback.feedback_votes.any? { |v| v.user_id == user.id } : false
        {
          id:          feedback.id,
          category:    feedback.category,
          title:       feedback.title,
          description: feedback.description,
          rating:      feedback.rating,
          status:      feedback.status,
          votes_count: feedback.votes_count,
          user_voted:  voted,
          created_at:  feedback.created_at
        }
      end
    end
  end
end
