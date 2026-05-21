# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('MAILER_FROM_EMAIL', 'noreply@prostaff.gg')
  layout 'mailer'

  private

  def frontend_url_for(record)
    source = record.source_app.presence || 'prostaff'
    Constants::SOURCE_APP_URLS.fetch(source, ENV.fetch('PROSTAFF_URL', 'https://prostaff.gg'))
  end
end
