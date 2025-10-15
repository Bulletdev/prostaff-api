FactoryBot.define do
  factory :vod_timestamp do
    association :vod_review
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
    end

    trait :critical do
      importance { 'critical' }
    end

    trait :important do
      importance { 'high' }
    end
  end
end
