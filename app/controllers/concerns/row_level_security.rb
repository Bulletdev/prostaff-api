# frozen_string_literal: true

module RowLevelSecurity
  extend ActiveSupport::Concern

  included do
    around_action :with_rls_context
  end

  def with_rls_context
    return yield unless current_user && current_organization

    set_thread_locals
    run_with_rls_transaction { yield }
  ensure
    clear_thread_locals
  end

  private

  def set_thread_locals
    Thread.current[:current_organization_id] = current_organization.id
    Thread.current[:current_user_id] = current_user.id
    Thread.current[:current_user_role] = current_user.role
  end

  def clear_thread_locals
    Thread.current[:current_organization_id] = nil
    Thread.current[:current_user_id] = nil
    Thread.current[:current_user_role] = nil
  end

  def run_with_rls_transaction
    ActiveRecord::Base.transaction do
      set_postgres_session_vars
      yield
      reset_postgres_session_vars
    end
  end

  def set_postgres_session_vars
    connection = ActiveRecord::Base.connection
    connection.exec_query('SET LOCAL app.current_user_id = $1', 'SET LOCAL', [[nil, current_user.id.to_s]])
    connection.exec_query('SET LOCAL app.current_organization_id = $1', 'SET LOCAL',
                          [[nil, current_organization.id.to_s]])
    connection.exec_query('SET LOCAL app.user_role = $1', 'SET LOCAL', [[nil, current_user.role.to_s]])
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.warn("RLS SET LOCAL failed: #{e.message}. Using thread-local only.")
  end

  def reset_postgres_session_vars
    connection = ActiveRecord::Base.connection
    connection.execute('RESET app.current_user_id;')
    connection.execute('RESET app.current_organization_id;')
    connection.execute('RESET app.user_role;')
  rescue ActiveRecord::StatementInvalid
    # Ignore reset errors
  end
end
