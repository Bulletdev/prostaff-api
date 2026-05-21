# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def password_reset(user, reset_token, frontend_url_override = nil)
    @user = user
    base = frontend_url_override || frontend_url_for(user)
    parsed_uri = URI.parse(base)
    unless parsed_uri.is_a?(URI::HTTP)
      raise ArgumentError, "Frontend URL must use http or https (got: #{parsed_uri.scheme.inspect})"
    end

    @reset_url = "#{base}/reset-password?token=#{reset_token.token}"
    @expires_in = ((reset_token.expires_at - Time.current) / 60).to_i

    mail(to: @user.email, subject: 'Redefinicao de senha - ProStaff')
  end

  def password_reset_confirmation(user)
    @user = user
    @frontend_url = frontend_url_for(user)
    mail(to: @user.email, subject: 'Senha redefinida com sucesso - ProStaff')
  end

  def welcome(user)
    @user = user
    @frontend_url = frontend_url_for(user)
    mail(to: @user.email, subject: "Bem-vindo ao ProStaff, #{user.full_name}!")
  end

  def trial_expired(user)
    @user = user
    @organization = user.organization
    mail(to: @user.email, subject: 'Seu periodo de teste ProStaff encerrou')
  end

  def trial_expiring_soon(user, days_remaining)
    @user = user
    @organization = user.organization
    @days_remaining = days_remaining
    mail(to: @user.email, subject: "Seu teste ProStaff expira em #{days_remaining} dia(s)")
  end
end
