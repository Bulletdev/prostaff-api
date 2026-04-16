# frozen_string_literal: true

# Provides lightweight HTTP-level response caching for controller actions.
#
# The cache is skipped entirely when query parameters are present (filters,
# search terms, pagination) so that parameterised requests always hit the
# database and receive accurate results.
#
# A response header `X-Cache-Hit: true/false` is set on every eligible request
# so that clients and reverse proxies can observe cache behaviour.
#
# Cache keys are organisation-scoped to preserve multi-tenant isolation.
#
# @example Cache the index action for 5 minutes
#   class PlayersController < Api::V1::BaseController
#     include Cacheable
#
#     def index
#       data = cache_response('players', expires_in: 5.minutes) do
#         PlayerSerializer.render_as_hash(organization_scoped(Player).all)
#       end
#       render_success(players: data)
#     end
#   end
module Cacheable
  extend ActiveSupport::Concern

  # Fetches the value from the Rails cache or executes the block and stores
  # the result.  Caching is bypassed when any non-routing params are present.
  #
  # @param key [String] short identifier appended to the org-scoped cache key
  # @param expires_in [ActiveSupport::Duration] cache TTL (default 5 minutes)
  # @yield the block whose return value will be cached
  # @return [Object] cached or freshly computed value
  def cache_response(key, expires_in: 5.minutes, &block)
    return block.call if params.except(:controller, :action, :format).keys.any?

    cache_key = build_cache_key(key)
    cache_hit = Rails.cache.exist?(cache_key)
    response.set_header('X-Cache-Hit', cache_hit.to_s)

    Rails.cache.fetch(cache_key, expires_in: expires_in, &block)
  end

  private

  # Builds an organisation-scoped cache key to prevent cross-tenant leakage.
  # Falls back to 'public' scope for unauthenticated actions (e.g. tournament index).
  #
  # @param key [String] action-specific key segment
  # @return [String] full namespaced cache key
  def build_cache_key(key)
    org_segment = current_organization&.id || 'public'
    "v1:#{org_segment}:#{key}"
  end
end
