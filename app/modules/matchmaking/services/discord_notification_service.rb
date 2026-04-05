class DiscordNotificationService
      WEBHOOK_URL = ENV.fetch('SCRIMS_LOL_DISCORD_WEBHOOK_URL', nil)

      def self.notify_accepted(scrim_request)
        return unless WEBHOOK_URL.present?

        payload = {
          embeds: [{
            title: '✅ Scrim Request Accepted!',
            color: 0x00D364,
            fields: [
              { name: 'From', value: scrim_request.requesting_organization.name, inline: true },
              { name: 'To',   value: scrim_request.target_organization.name,    inline: true },
              { name: 'Game', value: scrim_request.game.humanize,               inline: true }
            ],
            footer: { text: 'scrims.lol — powered by ProStaff.gg' },
            timestamp: Time.current.iso8601
          }]
        }

        post_webhook(payload)
      end

      def self.notify_declined(scrim_request)
        return unless WEBHOOK_URL.present?

        payload = {
          embeds: [{
            title: '❌ Scrim Request Declined',
            color: 0xFF4444,
            fields: [
              { name: 'From', value: scrim_request.requesting_organization.name, inline: true },
              { name: 'To',   value: scrim_request.target_organization.name,    inline: true }
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
          f.response :raise_error
          f.adapter Faraday.default_adapter
        end
        conn.post('', payload)
      rescue Faraday::Error => e
        Rails.logger.warn("[DiscordWebhook] Failed to send notification: #{e.message}")
      end
end
