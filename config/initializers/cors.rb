# frozen_string_literal: true

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # The fallback (second argument) must be a single string separated by commas
    origins ENV.fetch('CORS_ORIGINS', 'http://localhost:3000,http://localhost:5173,http://localhost:8888,http://localhost:4444,https://scrims.lol,https://prostaff.vercel.app,https://prostaff.gg,https://www.prostaff.gg,https://api.prostaff.gg,https://status.prostaff.gg,https://docs.prostaff.gg,https://arenabr.gg,https://www.arenabr.gg').split(',')

    resource '*',
             headers: :any,
             methods: %i[get post put patch delete options head],
             credentials: true,
             max_age: 86_400
  end
end
