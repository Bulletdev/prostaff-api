# frozen_string_literal: true

# Minimal ScoutingTarget serializer used as nested association inside MarketRegistrationSerializer.
# Only exposes fields needed for GCD market data context.
class MarketRegistrationTargetSerializer < Blueprinter::Base
  identifier :id

  fields :summoner_name, :region
end
