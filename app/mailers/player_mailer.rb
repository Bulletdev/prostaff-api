# frozen_string_literal: true

class PlayerMailer < ApplicationMailer
  def password_reset(player, reset_token, frontend_url_override = nil)
    @player = player
    base = frontend_url_override || frontend_url_for(player)
    parsed_uri = URI.parse(base)
    unless parsed_uri.is_a?(URI::HTTP)
      raise ArgumentError, "Frontend URL must use http or https (got: #{parsed_uri.scheme.inspect})"
    end

    @reset_url = "#{base}/reset-password?token=#{reset_token.token}"
    @expires_in = ((reset_token.expires_at - Time.current) / 60).to_i

    mail(to: @player.player_email, subject: 'Redefinicao de senha - ArenaBR')
  end

  def password_reset_confirmation(player)
    @player = player
    @frontend_url = frontend_url_for(player)
    mail(to: @player.player_email, subject: 'Senha redefinida com sucesso - ArenaBR')
  end
end
