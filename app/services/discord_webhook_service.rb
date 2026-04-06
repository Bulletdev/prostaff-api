# frozen_string_literal: true

# DiscordWebhookService — Forwards scrim chat messages to the ProStaff Discord bot.
#
# The bot exposes a WEBrick HTTP server that creates a per-scrim thread in a
# configured text channel and relays messages to it.
#
# Configuration (env vars, all optional — Discord integration is skipped when absent):
#   DISCORD_BOT_WEBHOOK_URL    — e.g. http://bot-host:4567
#   DISCORD_BOT_WEBHOOK_SECRET — shared secret checked by the bot
#   DISCORD_GUILD_ID           — the Discord guild the bot serves
class DiscordWebhookService
  WEBHOOK_URL    = ENV['DISCORD_BOT_WEBHOOK_URL']
  WEBHOOK_SECRET = ENV['DISCORD_BOT_WEBHOOK_SECRET']
  GUILD_ID       = ENV['DISCORD_GUILD_ID']

  # Enqueues a background job to notify the Discord bot of a new scrim message.
  # Silently skips if Discord is not configured.
  #
  # @param message [ScrimMessage]
  # @return [void]
  def self.notify_new_message(message)
    return unless configured?

    DiscordScrimMessageJob.perform_later(message.id)
  end

  def self.configured?
    WEBHOOK_URL.present? && GUILD_ID.present?
  end
end
