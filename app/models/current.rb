# frozen_string_literal: true

# Thread-safe storage for request-scoped data
# Use Current.organization_id instead of Thread.current[:organization_id]
class Current < ActiveSupport::CurrentAttributes
  attribute :organization_id, :user_id, :user_role
end
