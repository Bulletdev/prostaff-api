# frozen_string_literal: true

FactoryBot.define do
  factory :schedule do
    association :organization
    title      { Faker::Lorem.sentence(word_count: 3) }
    event_type { 'scrim' }
    start_time { 2.days.from_now }
    end_time   { 2.days.from_now + 2.hours }
    status     { 'scheduled' }

    trait :past do
      start_time { 2.days.ago }
      end_time   { 2.days.ago + 2.hours }
    end

    trait :cancelled do
      status { 'cancelled' }
    end
  end
end
