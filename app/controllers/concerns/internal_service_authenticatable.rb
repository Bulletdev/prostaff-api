# frozen_string_literal: true

module InternalServiceAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_internal_service!
  end

  private

  def authenticate_internal_service!
    token    = request.headers['Authorization']&.delete_prefix('Bearer ')
    expected = ENV.fetch('INTERNAL_JWT_SECRET', nil)

    return if expected.present? && token.present? &&
              ActiveSupport::SecurityUtils.secure_compare(token, expected)

    render json: { error: 'unauthorized' }, status: :unauthorized
  end
end
