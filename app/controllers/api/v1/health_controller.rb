# frozen_string_literal: true

module Api
  module V1
    class HealthController < ApplicationController
      skip_before_action :authenticate_request!, only: [:index, :db]

      def index
        render json: {
          status: 'ok',
          timestamp: Time.current,
          environment: Rails.env,
          version: '1.0.0'
        }
      end

      def db
        begin
          # Test database connection
          ActiveRecord::Base.connection.execute('SELECT 1')

          # Get database info
          db_info = ActiveRecord::Base.connection.execute(
            "SELECT current_database() as db, current_user as user, version() as version"
          ).first

          # Check RLS status
          rls_status = ActiveRecord::Base.connection.execute(
            "SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public' AND tablename IN ('users', 'players', 'matches') ORDER BY tablename"
          ).to_a

          # Test simple query
          user_count = User.unscoped.count
          player_count = Player.unscoped.count

          render json: {
            status: 'ok',
            database: {
              name: db_info['db'],
              user: db_info['user'],
              version: db_info['version']&.split(' ')&.first(3)&.join(' ')
            },
            rls_status: rls_status.map { |r| { table: r['tablename'], enabled: r['rowsecurity'] } },
            counts: {
              users: user_count,
              players: player_count
            }
          }
        rescue StandardError => e
          render json: {
            status: 'error',
            error: {
              class: e.class.name,
              message: e.message,
              backtrace: e.backtrace.first(5)
            }
          }, status: :internal_server_error
        end
      end
    end
  end
end
