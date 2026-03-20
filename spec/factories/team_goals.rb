# frozen_string_literal: true

FactoryBot.define do
  factory :team_goal do
    association :organization
    title        { Faker::Lorem.sentence(word_count: 4) }
    category     { 'performance' }
    metric_type  { 'win_rate' }
    target_value { 65.0 }
    current_value { 52.0 }
    start_date   { Date.current }
    end_date     { Date.current + 30.days }
    status       { 'active' }
    progress     { 0 }

    trait :completed do
      status   { 'completed' }
      progress { 100 }
    end

    trait :for_player do
      association :player
    end
  end
end
