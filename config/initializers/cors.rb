# frozen_string_literal: true

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # The fallback (second argument) must be a single string separated by commas
origins ENV.fetch('CORS_ORIGINS', 'http://localhost:5173,http://localhost:8888,https://prostaff.vercel.app,https://prostaff.gg,https://api.prostaff.gg').split(',')

    resource '*',
             headers: :any,
             methods: %i[get post put patch delete options head],
             credentials: true,
             max_age: 86_400
  end
end
