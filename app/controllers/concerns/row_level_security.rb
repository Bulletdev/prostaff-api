# frozen_string_literal: true

module RowLevelSecurity
  extend ActiveSupport::Concern

  included do
    around_action :with_rls_context
  end

  def with_rls_context
    return yield unless current_user && current_organization

    # Set thread-local variable for application-level scoping
    # This is the primary mechanism since RLS might not work with poolers
    Thread.current[:current_organization_id] = current_organization.id
    Thread.current[:current_user_id] = current_user.id
    Thread.current[:current_user_role] = current_user.role

    # Try to set PostgreSQL session variables for RLS
    # This works in direct connections but may fail with transaction-mode poolers
    ActiveRecord::Base.transaction do
      begin
        connection = ActiveRecord::Base.connection
        # Use parameterized queries to prevent SQL injection
        connection.exec_query(
          'SET LOCAL app.current_user_id = $1',
          'SET LOCAL',
          [[nil, current_user.id.to_s]]
        )
        connection.exec_query(
          'SET LOCAL app.current_organization_id = $1',
          'SET LOCAL',
          [[nil, current_organization.id.to_s]]
        )
        connection.exec_query(
          'SET LOCAL app.user_role = $1',
          'SET LOCAL',
          [[nil, current_user.role.to_s]]
        )
      rescue ActiveRecord::StatementInvalid => e
        # SET LOCAL might fail outside transactions on some poolers
        Rails.logger.warn("RLS SET LOCAL failed: #{e.message}. Using thread-local only.")
      end

      yield

      # Reset PostgreSQL variables within the same transaction
      begin
        connection.execute('RESET app.current_user_id;')
        connection.execute('RESET app.current_organization_id;')
        connection.execute('RESET app.user_role;')
      rescue ActiveRecord::StatementInvalid
        # Ignore reset errors
      end
    end
  ensure
    # Reset thread-local variables
    Thread.current[:current_organization_id] = nil
    Thread.current[:current_user_id] = nil
    Thread.current[:current_user_role] = nil
  end
end
