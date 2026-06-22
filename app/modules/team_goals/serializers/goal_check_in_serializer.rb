# frozen_string_literal: true

# Serializer for GoalCheckIn — append-only progress record for a TeamGoal.
class GoalCheckInSerializer < Blueprinter::Base
  identifier :id

  fields :measured_value, :note, :source, :created_at

  field :created_by_id

  association :created_by, blueprint: UserSerializer
end
