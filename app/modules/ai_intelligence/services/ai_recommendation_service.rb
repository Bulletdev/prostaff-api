# frozen_string_literal: true

# HTTP client for the ProStaff ML AI Service (FastAPI).
#
# Calls POST /recommend on the ML service and returns top-N champion picks
# with composite scores. Falls back to DraftSuggester (Ruby cosine-similarity
# implementation) when the ML service is unreachable or returns an error.
#
# Configuration:
#   AI_SERVICE_URL — base URL of the FastAPI service, e.g. http://ai-service:8001
#                    Defaults to http://localhost:8001 for local development.
#
# Source tagging:
#   Returns { source: "ml_v2" } when ML responded successfully.
#   Returns { source: "legacy" } when falling back to DraftSuggester.
#
# @example
#   result = AiRecommendationService.call(
#     our_picks:      %w[Jinx Thresh Azir Gnar],
#     opponent_picks: %w[Caitlyn Nautilus Syndra Renekton Graves],
#     our_bans:       [],
#     opponent_bans:  [],
#     patch:          "16.08",
#     league:         "LCK"
#   )
#   result[:source]          # => "ml_v2"
#   result[:recommendations] # => [{ champion: "Lissandra", score: 0.52, ... }]
class AiRecommendationService
  class MlServiceError < StandardError; end

  REQUEST_TIMEOUT = 5

  def self.call(**)
    new(**).call
  end

  def initialize(our_picks:, opponent_picks:, our_bans: [], opponent_bans: [], patch: nil, league: nil)
    @our_picks      = our_picks
    @opponent_picks = opponent_picks
    @our_bans       = our_bans
    @opponent_bans  = opponent_bans
    @patch          = patch
    @league         = league
    @base_url       = ENV.fetch('AI_SERVICE_URL', 'http://localhost:8001')
  end

  def call
    call_ml_service
  rescue MlServiceError => e
    Rails.logger.warn("[AiRecommendationService] ML service unavailable, using legacy fallback: #{e.message}")
    legacy_fallback
  end

  private

  def call_ml_service
    response = connection.post('/recommend') do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = build_payload.to_json
      req.options.timeout = REQUEST_TIMEOUT
    end

    raise MlServiceError, "ML service returned #{response.status}" unless response.success?

    body = JSON.parse(response.body, symbolize_names: true)
    {
      source: body[:source] || 'ml_v2',
      model_version: body[:model_version],
      recommendations: body[:recommendations] || []
    }
  rescue Faraday::TimeoutError => e
    raise MlServiceError, "timeout: #{e.message}"
  rescue Faraday::ConnectionFailed => e
    raise MlServiceError, "connection failed: #{e.message}"
  rescue Faraday::Error => e
    raise MlServiceError, "network error: #{e.message}"
  rescue JSON::ParserError => e
    raise MlServiceError, "invalid JSON response: #{e.message}"
  end

  def legacy_fallback
    suggestions = DraftSuggester.call(team_a: @our_picks, team_b: @opponent_picks)
    {
      source: 'legacy',
      model_version: nil,
      recommendations: suggestions.map { |champ| { champion: champ, score: nil } }
    }
  end

  def build_payload
    {
      our_picks: @our_picks,
      opponent_picks: @opponent_picks,
      our_bans: @our_bans,
      opponent_bans: @opponent_bans,
      patch: @patch,
      league: @league
    }
  end

  def connection
    @connection ||= Faraday.new(url: @base_url) do |f|
      f.adapter Faraday.default_adapter
    end
  end
end
