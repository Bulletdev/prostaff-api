# frozen_string_literal: true

# Load dependencies first
require Rails.root.join('app/serializers/organization_serializer').to_s
require Rails.root.join('app/serializers/user_serializer').to_s

# Load Strategy module serializers
require Rails.root.join('app/modules/strategy/serializers/draft_plan_serializer').to_s
require Rails.root.join('app/modules/strategy/serializers/tactical_board_serializer').to_s
