# frozen_string_literal: true

FactoryBot.define do
  factory :scrim do
    association :organization
    scheduled_at  { 2.days.from_now }
    games_planned { 3 }
    game_results  { [] }

    trait :past do
      scheduled_at { 3.days.ago }
    end

    trait :completed do
      games_planned  { 3 }
      games_completed { 3 }
    end
  end
end
