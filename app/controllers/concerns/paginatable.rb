# frozen_string_literal: true

# Paginatable Concern
#
# Provides pagination helper methods for controllers using Kaminari.
# Include this concern to add consistent pagination metadata to API responses.
#
# Example:
#   class MyController < ApplicationController
#     include Paginatable
#
#     def index
#       records = Model.page(params[:page]).per(params[:per_page])
#       render json: { data: records, meta: pagination_meta(records) }
#     end
#   end
#
module Paginatable
  extend ActiveSupport::Concern

  private

  # Builds pagination metadata for a Kaminari paginated collection
  #
  # @param collection [ActiveRecord::Relation] Kaminari paginated collection
  # @return [Hash] Pagination metadata
  #
  # @example
  #   users = User.page(1).per(20)
  #   pagination_meta(users)
  #   # => {
  #   #   current_page: 1,
  #   #   total_pages: 5,
  #   #   total_count: 100,
  #   #   per_page: 20
  #   # }
  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      per_page: collection.limit_value
    }
  end
end
