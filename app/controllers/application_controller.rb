# frozen_string_literal: true

# Base Application Controller
#
# Root controller for the entire API application. All controllers inherit from this class.
# Provides fundamental API configuration and sets JSON as the default response format.
#
# This controller:
# - Inherits from ActionController::API for API-only functionality
# - Sets JSON as the default response format for all endpoints
# - Provides the foundation for API behavior across the application
#
# Note: CSRF protection is disabled as this is an API-only application.
# Specific controllers (like Api::V1::BaseController) add authentication and authorization.
#
# @example Inheriting in a namespaced controller
#   class Api::V1::BaseController < ApplicationController
#     include Authenticatable
#   end
class ApplicationController < ActionController::API
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  # protect_from_forgery with: :exception

  before_action :set_default_response_format

  private

  def set_default_response_format
    request.format = :json
  end
end
