# frozen_string_literal: true

module Strategy
  module Serializers
    # Serializer for DraftPlan model
    # Renders draft strategy data with scenarios and analysis
    class DraftPlanSerializer < Blueprinter::Base
      identifier :id

      fields :opponent_team, :side, :patch_version, :notes
      fields :our_bans, :opponent_bans, :priority_picks, :if_then_scenarios
      fields :is_active
      fields :created_at, :updated_at

      field :side_display do |plan|
        plan.side_display
      end

      field :total_scenarios do |plan|
        plan.total_scenarios
      end

      field :priority_champions do |plan|
        plan.priority_champions
      end

      field :blind_pick_ready do |plan|
        plan.blind_pick_ready?
      end

      association :organization, blueprint: ::OrganizationSerializer
      association :created_by, blueprint: ::UserSerializer
      association :updated_by, blueprint: ::UserSerializer
    end
  end
end
