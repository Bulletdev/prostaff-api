# frozen_string_literal: true

# Proxy controller that inherits from the modularized Authentication controller
module Api
  module V1
    class AuthController < ::Authentication::Controllers::AuthController
      # All functionality is inherited from Authentication::Controllers::AuthController
      # This controller exists only for backwards compatibility with existing routes
    end
  end
end
