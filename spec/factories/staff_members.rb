# frozen_string_literal: true

FactoryBot.define do
  factory :staff_member do
    association :organization
    name   { Faker::Name.name }
    role   { 'analyst' }
    status { 'active' }
    line   { 'main' }

    trait :head_coach do
      role { 'head_coach' }
    end

    trait :analyst do
      role { 'analyst' }
    end

    trait :inactive do
      status { 'inactive' }
    end
  end
end
