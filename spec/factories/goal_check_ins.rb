# frozen_string_literal: true

FactoryBot.define do
  factory :goal_check_in do
    association :team_goal
    association :organization

    measured_value { 58.5 }
    source         { 'manual' }
    note           { nil }

    trait :auto do
      source       { 'auto' }
      created_by   { nil }
    end

    trait :with_note do
      note { 'Progress looks steady this week.' }
    end
  end
end
