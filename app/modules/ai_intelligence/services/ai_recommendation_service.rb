# frozen_string_literal: true

# HTTP client for the ProStaff ML AI Service (FastAPI).
#
# Calls POST /recommend on the ML service and returns top-N champion picks
# with composite scores. Falls back to DraftSuggester (Ruby cosine-similarity
# implementation) when the ML service is unreachable, returns an error, is
# disabled via kill switch, or when the circuit breaker is open.
#
# Configuration:
#   AI_SERVICE_URL      — base URL of the FastAPI service, e.g. http://ai-service:8001
#                         Defaults to http://localhost:8001 for local development.
#   ML_SERVICE_ENABLED  — set to 'false' to disable all ML calls (kill switch).
#
# Source tagging:
#   Returns { source: "ml_v2" }  when ML responded successfully.
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

  REQUEST_TIMEOUT = ENV.fetch('ML_SERVICE_TIMEOUT', '5').to_i

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
  end

  def call
    call_ml_service
  rescue MlServiceClient::MlServiceDisabledError, MlServiceClient::MlCircuitOpenError => e
    Rails.logger.info("[AiRecommendationService] ML unavailable (#{e.class.name.split('::').last}), using legacy fallback: #{e.message}")
    legacy_fallback
  rescue MlServiceError => e
    Rails.logger.warn("[AiRecommendationService] ML service error, using legacy fallback: #{e.message}")
    legacy_fallback
  end

  private

  def call_ml_service
    body = MlServiceClient.post('/recommend', build_payload, timeout: REQUEST_TIMEOUT)
    result = {
      source: body[:source] || 'ml_v2',
      model_version: body[:model_version],
      recommendations: body[:recommendations] || []
    }

    if result[:source] == 'ml_v2'
      win_prob = result[:recommendations].first&.dig(:win_probability)&.to_f || 0.5
      PredictionLogger.log(
        blue_picks:         @our_picks,
        red_picks:          @opponent_picks,
        predicted_win_prob: win_prob,
        source:             result[:source],
        model_version:      result[:model_version],
        patch:              @patch,
        league:             @league
      )
    end

    result
  rescue MlServiceClient::MlServiceError => e
    raise MlServiceError, e.message
  end

  def legacy_fallback
    suggestions = DraftSuggester.call(team_a: @our_picks, team_b: @opponent_picks)
    {
      source: 'legacy',
      model_version: nil,
      recommendations: suggestions.map do |champ|
        {
          champion: champ,
          score: nil,
          win_probability: nil,
          synergy_score: nil,
          counter_score: nil,
          reasoning_tokens: []
        }
      end
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
end
