# frozen_string_literal: true

# HTTP client for the ProStaff ML AI Service (FastAPI) — win probability endpoint.
#
# Calls POST /win-probability on the ML service and returns win probability
# with confidence score. Returns nil if the ML service is unreachable, times
# out, returns an invalid response, is disabled via kill switch, or when the
# circuit breaker is open — allowing callers to fall back gracefully.
#
# Configuration:
#   AI_SERVICE_URL     — base URL of the FastAPI service, e.g. http://ai-service:8001
#                        Defaults to http://localhost:8001 for local development.
#   ML_SERVICE_ENABLED — set to 'false' to disable all ML calls (kill switch).
#
# @example
#   result = MlDraftService.call(
#     team_a: %w[Jinx Thresh Azir Gnar Renekton],
#     team_b: %w[Caitlyn Nautilus Syndra Graves Camille],
#     patch:  "16.08",
#     league: "LCK"
#   )
#   result # => { win_probability: 0.6134, confidence: 0.81, source: "ml_v2" }
#   # or nil if the ML service failed / is disabled / circuit is open
class MlDraftService
  REQUEST_TIMEOUT = 3

  def self.call(**)
    new(**).call
  end

  def initialize(team_a:, team_b:, patch: nil, league: nil, side: nil)
    @team_a  = team_a
    @team_b  = team_b
    @patch   = patch
    @league  = league
    @side    = side
  end

  def call
    body = MlServiceClient.post('/win-probability', build_payload, timeout: REQUEST_TIMEOUT)

    unless body.is_a?(Hash) && body[:win_probability]
      Rails.logger.warn("[MlDraftService] Unexpected response shape from ML service")
      return nil
    end

    {
      win_probability: body[:win_probability].to_f,
      confidence:      body[:confidence].to_f,
      source:          'ml_v2'
    }
  rescue MlServiceClient::MlServiceDisabledError, MlServiceClient::MlCircuitOpenError
    # Kill switch active or circuit open — return nil silently (no error-level log)
    nil
  rescue MlServiceClient::MlServiceError => e
    Rails.logger.warn("[MlDraftService] ML service unavailable: #{e.message}")
    nil
  end

  private

  def build_payload
    {
      team_a_picks: @team_a,
      team_b_picks: @team_b,
      patch:        @patch,
      league:       @league,
      side:         @side
    }
  end
end
