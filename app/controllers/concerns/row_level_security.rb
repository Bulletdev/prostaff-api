# frozen_string_literal: true

module RowLevelSecurity
  extend ActiveSupport::Concern

  included do
    around_action :with_rls_context
  end

  def with_rls_context
    return yield unless current_user && current_organization

    # Set PostgreSQL session variables for RLS
    ActiveRecord::Base.connection.execute(
      "SET LOCAL app.current_user_id = '#{current_user.id}';"
    )
    ActiveRecord::Base.connection.execute(
      "SET LOCAL app.current_organization_id = '#{current_organization.id}';"
    )
    ActiveRecord::Base.connection.execute(
      "SET LOCAL app.user_role = '#{current_user.role}';"
    )

    # Set thread-local variable for application-level scoping
    # This is needed because PostgreSQL RLS doesn't apply to table owners (postgres user)
    Thread.current[:current_organization_id] = current_organization.id
    Thread.current[:current_user_id] = current_user.id
    Thread.current[:current_user_role] = current_user.role

    yield
  ensure
    # Reset PostgreSQL variables
    begin
      ActiveRecord::Base.connection.execute('RESET app.current_user_id;')
      ActiveRecord::Base.connection.execute('RESET app.current_organization_id;')
      ActiveRecord::Base.connection.execute('RESET app.user_role;')
    rescue ActiveRecord::StatementInvalid
      # Connection might be closed, ignore
    end

    # Reset thread-local variables
    Thread.current[:current_organization_id] = nil
    Thread.current[:current_user_id] = nil
    Thread.current[:current_user_role] = nil
  end
end
