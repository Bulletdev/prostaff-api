# frozen_string_literal: true

FactoryBot.define do
  factory :player_rank_snapshot do
    association :player

    queue_type     { 'RANKED_SOLO_5x5' }
    tier           { 'GOLD' }
    rank           { 'II' }
    league_points  { 50 }
    wins           { 30 }
    losses         { 20 }
    recorded_on    { Date.current }

    trait :flex do
      queue_type { 'RANKED_FLEX_SR' }
    end

    trait :diamond do
      tier { 'DIAMOND' }
      rank { 'II' }
    end

    trait :master do
      tier { 'MASTER' }
      rank { nil }
    end
  end
end
