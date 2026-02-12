# frozen_string_literal: true

Rails.application.config.after_initialize do
  ActiveRecord::Base.connection_pool.with_connection do |conn|
    begin
      conn.execute('CREATE SCHEMA IF NOT EXISTS auth;')
    rescue ActiveRecord::StatementInvalid
      # Schema already exists or insufficient permissions
      nil
    end
  end
end
