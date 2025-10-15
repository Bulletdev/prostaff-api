# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('MAILER_FROM_EMAIL', 'noreply@prostaff.gg')
  layout 'mailer'
end
