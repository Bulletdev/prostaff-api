# frozen_string_literal: true

# Mailer for contact form submissions from prostaff.gg/contact
class ContactMailer < ApplicationMailer
  def new_message(name:, email:, subject:, message:)
    @name = name
    @email = email
    @subject = subject
    @message = message

    mail(
      to: ENV.fetch('ADMIN_EMAIL', 'hello@prostaff.gg'),
      reply_to: email,
      subject: "[ProStaff Contact] #{subject}"
    )
  end
end
