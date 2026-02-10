# frozen_string_literal: true

# Proxy controller that inherits from the modularized Players controller
# This allows seamless migration to modular architecture without breaking existing routes
module Api
  module V1
    class PlayersController < ::Players::Controllers::PlayersController
      # All functionality is inherited from Players::Controllers::PlayersController
      # This controller exists only for backwards compatibility with existing routes
    end
  end
end
