# frozen_string_literal: true

# Sends Discord webhook notifications for scrim-related events.
# Webhook URL is configured via SCRIMS_LOL_DISCORD_WEBHOOK_URL env variable.
class DiscordWebhookService
  WEBHOOK_URL = ENV.fetch('SCRIMS_LOL_DISCORD_WEBHOOK_URL', nil)

  def self.notify_scrim_created(scrim)
    return unless WEBHOOK_URL.present?

    org_name = scrim.organization.name
    opponent = scrim.opponent_team&.name || 'TBD'
    scheduled = scrim.scheduled_at&.strftime('%d/%m %H:%M') || 'TBD'

    payload = {
      embeds: [{
        title: 'New Scrim Scheduled',
        color: 0xC89B3C,
        fields: [
          { name: 'Team',      value: org_name,  inline: true },
          { name: 'Opponent',  value: opponent,  inline: true },
          { name: 'Scheduled', value: scheduled, inline: true }
        ],
        footer: { text: 'scrims.lol — powered by ProStaff.gg' },
        timestamp: Time.current.iso8601
      }]
    }

    post_webhook(payload)
  end

  # Posts a notification when a new scrim chat message is sent.
  #
  # @param scrim_message [ScrimMessage]
  # @return [void]
  def self.notify_new_message(scrim_message)
    return unless WEBHOOK_URL.present?

    payload = {
      embeds: [{
        title: "New message in scrim #{scrim_message.scrim_id}",
        description: scrim_message.content.truncate(200),
        color: 0x5865F2,
        fields: [
          { name: 'Author',       value: scrim_message.user.full_name,    inline: true },
          { name: 'Organization', value: scrim_message.organization.name, inline: true }
        ],
        footer: { text: 'scrims.lol — powered by ProStaff.gg' },
        timestamp: scrim_message.created_at.iso8601
      }]
    }

    post_webhook(payload)
  end

  def self.post_webhook(payload)
    conn = Faraday.new(url: WEBHOOK_URL) do |f|
      f.request :json
      f.adapter Faraday.default_adapter
    end
    conn.post('', payload)
  rescue Faraday::Error => e
    Rails.logger.warn("[ScrimsDiscordWebhook] #{e.message}")
  end
end
