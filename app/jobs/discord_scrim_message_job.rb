# frozen_string_literal: true

# Sends a scrim chat message notification to the ProStaff Discord bot webhook.
#
# Runs in the background so Action Cable broadcasts are never delayed by
# outbound HTTP. Failures are retried up to 3 times with exponential backoff.
class DiscordScrimMessageJob < ApplicationJob
  queue_as :default

  # Only retry on network-layer failures, not programming errors.
  retry_on Faraday::Error, wait: :polynomially_longer, attempts: 3

  ALLOWED_SCHEMES = %w[http https].freeze
  BLOCKED_HOSTS   = %w[169.254.169.254 metadata.google.internal].freeze

  def perform(message_id)
    message = ScrimMessage.includes(:scrim, :user, :organization).find_by(id: message_id)
    return unless message

    url    = DiscordWebhookService::WEBHOOK_URL
    secret = DiscordWebhookService::WEBHOOK_SECRET
    guild  = DiscordWebhookService::GUILD_ID

    return unless url.present? && guild.present?

    validated_url = validate_webhook_url!(url)
    payload = build_payload(message, guild, secret)
    post_to_bot(validated_url, payload)
  end

  private

  # Validates that the webhook URL is an http/https URL and not a known internal
  # cloud metadata address, protecting against SSRF from a misconfigured env var.
  def validate_webhook_url!(url)
    parsed = URI.parse(url)

    unless ALLOWED_SCHEMES.include?(parsed.scheme)
      raise ArgumentError, "[DiscordScrimMessageJob] Invalid webhook URL scheme: #{parsed.scheme}"
    end

    if BLOCKED_HOSTS.include?(parsed.host)
      raise ArgumentError, "[DiscordScrimMessageJob] Blocked webhook host: #{parsed.host}"
    end

    url
  rescue URI::InvalidURIError => e
    raise ArgumentError, "[DiscordScrimMessageJob] Malformed webhook URL: #{e.message}"
  end

  def build_payload(message, guild_id, secret)
    scrim    = message.scrim
    opponent = scrim.opponent_team&.name || 'Opponent'

    payload = {
      guild_id: guild_id,
      scrim_id: scrim.id.to_s,
      scrim_opponent: opponent,
      message: {
        content: message.content,
        user: { full_name: message.user.full_name },
        organization: { name: message.organization.name }
      }
    }
    payload[:secret] = secret if secret.present?
    payload
  end

  def post_to_bot(url, payload)
    conn = Faraday.new(url: url) do |f|
      f.request :json
      f.response :raise_error
      f.adapter Faraday.default_adapter
    end
    conn.post('/webhooks/scrim-message', payload)
  end
end
