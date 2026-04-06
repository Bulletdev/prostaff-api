# frozen_string_literal: true

# Sends Discord DMs to ProStaff users via the prostaff-discord-bot webhook.
#
# Requires users to have their discord_user_id saved in their profile.
# Only admins and owners of an org receive notifications.
#
# Called for:
#   - New scrim invite received  → notify target org admins/owners
#   - Invite accepted            → notify requesting org admins/owners
#   - Invite declined            → notify requesting org admins/owners
class DiscordDmService
  BOT_WEBHOOK_URL    = ENV.fetch('DISCORD_BOT_WEBHOOK_URL', nil)
  BOT_WEBHOOK_SECRET = ENV.fetch('DISCORD_BOT_WEBHOOK_SECRET', nil)

  GOLD  = 0xC89B3C
  GREEN = 0x00D364
  RED   = 0xFF4444

  def self.notify_new_invite(scrim_request)
    notify_org(
      org: scrim_request.target_organization,
      embed: invite_embed(scrim_request)
    )
  end

  def self.notify_accepted(scrim_request)
    notify_org(
      org: scrim_request.requesting_organization,
      embed: accepted_embed(scrim_request)
    )
  end

  def self.notify_declined(scrim_request)
    notify_org(
      org: scrim_request.requesting_organization,
      embed: declined_embed(scrim_request)
    )
  end

  # ── Private ────────────────────────────────────────────────────────────────

  def self.notify_org(org:, embed:)
    return unless BOT_WEBHOOK_URL.present?

    org.users
       .where(role: %w[owner admin])
       .where.not(discord_user_id: [nil, ''])
       .each do |user|
         send_dm(discord_user_id: user.discord_user_id, embed: embed)
       end
  end
  private_class_method :notify_org

  def self.send_dm(discord_user_id:, embed:)
    payload = {
      secret: BOT_WEBHOOK_SECRET,
      discord_user_id: discord_user_id,
      embed: embed
    }

    conn = Faraday.new do |f|
      f.request  :json
      f.adapter  Faraday.default_adapter
      f.options.timeout = 5
    end

    conn.post("#{BOT_WEBHOOK_URL}/webhooks/dm", payload)
  rescue Faraday::Error => e
    Rails.logger.warn("[DiscordDmService] DM to #{discord_user_id} failed: #{e.message}")
  end
  private_class_method :send_dm

  def self.invite_embed(req)
    proposed = req.proposed_at&.strftime('%d/%m/%Y às %H:%M UTC') || 'A combinar'

    fields = [
      { name: 'Adversário',    value: req.requesting_organization.name, inline: true },
      { name: 'Data Proposta', value: proposed,                         inline: true },
      { name: 'Jogos',         value: req.games_planned.to_s,           inline: true }
    ]
    fields << { name: 'Mensagem', value: req.message, inline: false } if req.message.present?

    {
      title: '🎮 Novo Convite de Scrim',
      color: GOLD,
      description: "**#{req.requesting_organization.name}** quer fazer um scrim com vocês!",
      fields: fields,
      footer: { text: 'scrims.lol — Acesse a plataforma para aceitar ou recusar' },
      timestamp: Time.current.iso8601
    }
  end
  private_class_method :invite_embed

  def self.accepted_embed(req)
    proposed = req.proposed_at&.strftime('%d/%m/%Y às %H:%M UTC') || 'A combinar'

    {
      title: '✅ Scrim Aceito!',
      color: GREEN,
      description: "**#{req.target_organization.name}** aceitou seu pedido de scrim.",
      fields: [
        { name: 'Adversário', value: req.target_organization.name, inline: true },
        { name: 'Data',       value: proposed,                     inline: true },
        { name: 'Jogos',      value: req.games_planned.to_s,       inline: true }
      ],
      footer: { text: 'scrims.lol' },
      timestamp: Time.current.iso8601
    }
  end
  private_class_method :accepted_embed

  def self.declined_embed(req)
    {
      title: '❌ Scrim Recusado',
      color: RED,
      description: "**#{req.target_organization.name}** recusou seu pedido de scrim.",
      fields: [
        { name: 'Adversário', value: req.target_organization.name, inline: true }
      ],
      footer: { text: 'scrims.lol' },
      timestamp: Time.current.iso8601
    }
  end
  private_class_method :declined_embed
end
