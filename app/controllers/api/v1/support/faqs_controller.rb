# frozen_string_literal: true

module Api
  module V1
    module Support
      # Controller for FAQ management
      class FaqsController < Api::V1::BaseController
        skip_before_action :authenticate_request!, only: %i[index show]
        before_action :set_faq, only: %i[show mark_helpful mark_not_helpful]

        # GET /api/v1/support/faq
        def index
          faqs = SupportFaq.published
                          .by_locale(params[:locale] || 'pt-BR')

          faqs = faqs.by_category(params[:category]) if params[:category].present?
          faqs = faqs.search(params[:q]) if params[:q].present?
          faqs = faqs.ordered

          result = paginate(faqs)

          render_success({
            faqs: result[:data].map { |f| serialize_faq(f) },
            pagination: result[:pagination],
            categories: SupportFaq::CATEGORIES
          })
        end

        # GET /api/v1/support/faq/:slug
        def show
          @faq.increment_view!

          render_success({ faq: serialize_faq_detail(@faq) })
        end

        # POST /api/v1/support/faq/:id/helpful
        def mark_helpful
          @faq.mark_helpful!

          render_success({
            helpful_count: @faq.helpful_count,
            helpfulness_ratio: @faq.helpfulness_ratio
          })
        end

        # POST /api/v1/support/faq/:id/not-helpful
        def mark_not_helpful
          @faq.mark_not_helpful!

          render_success({
            not_helpful_count: @faq.not_helpful_count,
            helpfulness_ratio: @faq.helpfulness_ratio
          })
        end

        private

        def set_faq
          @faq = SupportFaq.find_by!(slug: params[:slug] || params[:id])
        rescue ActiveRecord::RecordNotFound
          render_error('FAQ not found', :not_found)
        end

        def serialize_faq(faq)
          {
            id: faq.id,
            slug: faq.slug,
            question: faq.question,
            answer: faq.answer.truncate(200),
            category: faq.category,
            view_count: faq.view_count,
            helpful_count: faq.helpful_count,
            helpfulness_ratio: faq.helpfulness_ratio
          }
        end

        def serialize_faq_detail(faq)
          serialize_faq(faq).merge(
            answer: faq.answer, # Full answer
            keywords: faq.keywords,
            created_at: faq.created_at.iso8601,
            updated_at: faq.updated_at.iso8601
          )
        end
      end
    end
  end
end
