# frozen_string_literal: true

module Scrims
  module Services
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
            title: '📅 New Scrim Scheduled',
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
  end
end
