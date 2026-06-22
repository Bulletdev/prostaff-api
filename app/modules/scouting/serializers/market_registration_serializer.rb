# frozen_string_literal: true

# Serializer for MarketRegistration model.
# Renders public GCD (Global Contract Database) data from Leaguepedia.
class MarketRegistrationSerializer < Blueprinter::Base
  identifier :id

  fields :player_external_name, :team_name, :region, :role, :residency,
         :contract_end_date, :image_url, :source, :snapshot_date

  field :solo_queue_id do |reg|
    reg.effective_solo_queue_id
  end

  field :created_at do |record|
    record.created_at&.iso8601
  end

  association :scouting_target, blueprint: MarketRegistrationTargetSerializer
end
