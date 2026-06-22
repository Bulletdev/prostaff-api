# frozen_string_literal: true

FactoryBot.define do
  factory :roster_membership do
    association :organization
    association :player

    role      { 'mid' }
    status    { 'starter' }
    line      { 'main' }
    joined_at { Date.current - 90.days }

    trait :active do
      left_at    { nil }
      deleted_at { nil }
    end

    trait :inactive do
      left_at { Date.current - 30.days }
    end

    trait :with_contract do
      association :contract
    end
  end
end
