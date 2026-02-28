# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def password_reset(user, reset_token)
    @user = user
    @reset_token = reset_token
    frontend_url = ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
    parsed_uri = URI.parse(frontend_url)
    unless parsed_uri.is_a?(URI::HTTP)
      raise ArgumentError, "FRONTEND_URL must use http or https scheme (got: #{parsed_uri.scheme.inspect})"
    end

    @reset_url = "#{frontend_url}/reset-password?token=#{reset_token.token}"
    @expires_in = ((reset_token.expires_at - Time.current) / 60).to_i # minutes

    mail(
      to: @user.email,
      subject: 'Password Reset Request - ProStaff'
    )
  end

  def password_reset_confirmation(user)
    @user = user

    mail(
      to: @user.email,
      subject: 'Password Successfully Reset - ProStaff'
    )
  end

  def welcome(user)
    @user = user

    mail(
      to: @user.email,
      subject: 'Welcome to ProStaff!'
    )
  end
end
