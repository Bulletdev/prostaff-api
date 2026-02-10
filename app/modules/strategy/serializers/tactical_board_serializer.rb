# frozen_string_literal: true

module Strategy
  module Serializers
    # Serializer for TacticalBoard model
    # Renders tactical board data with positions and annotations
    class TacticalBoardSerializer < Blueprinter::Base
      identifier :id

      fields :title, :game_time
      fields :match_id, :scrim_id
      fields :map_state, :annotations
      fields :created_at, :updated_at

      field :total_players do |board|
        board.map_state.dig('players')&.size || 0
      end

      field :total_annotations do |board|
        board.annotations&.size || 0
      end

      field :auto_title do |board|
        board.auto_title
      end

      association :organization, blueprint: ::OrganizationSerializer
      association :created_by, blueprint: ::UserSerializer
      association :updated_by, blueprint: ::UserSerializer
    end
  end
end
