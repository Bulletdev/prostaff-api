# frozen_string_literal: true

Rails.application.config.after_initialize do
  ActiveRecord::Base.connection_pool.with_connection do |conn|
    conn.execute("CREATE SCHEMA IF NOT EXISTS auth;") rescue nil
  end
end
