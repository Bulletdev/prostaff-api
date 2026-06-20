# frozen_string_literal: true

FactoryBot.define do
  factory :vod_timestamp do
    # duration: nil skips the timestamp_within_duration validation so the factory
    # is not dependent on random duration/timestamp alignment.
    # Specs that need a specific duration create the vod_review explicitly.
    association :vod_review, duration: nil
    association :target_player, factory: :player
    association :created_by, factory: :user

    timestamp_seconds { rand(60..3600) }
    title { Faker::Lorem.sentence(word_count: 3) }
    description { Faker::Lorem.paragraph }
    category { %w[mistake good_play team_fight objective laning].sample }
    importance { %w[low normal high critical].sample }
    target_type { %w[player team opponent].sample }

    trait :mistake do
      category { 'mistake' }
      importance { %w[high critical].sample }
    end

    trait :good_play do
      category { 'good_play' }
      importance { 'normal' }
    end

    trait :critical do
      importance { 'critical' }
    end

    trait :important do
      importance { 'high' }
    end
  end
end
