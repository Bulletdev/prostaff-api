# frozen_string_literal: true

FactoryBot.define do
  factory :scrim_result_report do
    association :scrim_request
    association :organization
    status        { 'pending' }
    attempt_count { 0 }
    deadline_at   { 7.days.from_now }

    trait :reported do
      status      { 'reported' }
      reported_at { Time.current }
      game_outcomes { %w[win loss win] }
    end

    trait :confirmed do
      status        { 'confirmed' }
      reported_at   { 1.hour.ago }
      confirmed_at  { Time.current }
      game_outcomes { %w[win win loss] }
    end

    trait :disputed do
      status        { 'disputed' }
      reported_at   { 2.hours.ago }
      attempt_count { 1 }
      game_outcomes { %w[win loss win] }
    end
  end
end
