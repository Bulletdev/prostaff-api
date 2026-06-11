# frozen_string_literal: true

# Minimal player serializer for embedding in related resources (e.g. contracts).
# Does not include financial or sensitive fields.
class PlayerSummarySerializer < Blueprinter::Base
  identifier :id

  fields :summoner_name, :role, :status, :solo_queue_tier, :solo_queue_rank
end
