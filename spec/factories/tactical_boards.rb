# frozen_string_literal: true

FactoryBot.define do
  factory :tactical_board do
    association :organization
    association :created_by, factory: :user
    association :updated_by, factory: :user
    title { Faker::Lorem.sentence(word_count: 3) }
    game_time { '15:00' }
    map_state { { 'players' => [] } }
    annotations { [] }
    match { nil }
    scrim { nil }
  end
end
