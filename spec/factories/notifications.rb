# frozen_string_literal: true

FactoryBot.define do
  factory :notification do
    association :user
    title   { Faker::Lorem.sentence(word_count: 4) }
    message { Faker::Lorem.sentence }
    type    { 'info' }
    is_read { false }

    trait :read do
      is_read { true }
      read_at { Time.current }
    end

    trait :match_type do
      type { 'match' }
    end
  end
end
