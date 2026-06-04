# frozen_string_literal: true

FactoryBot.define do
  factory :scrim_message do
    association :scrim
    association :user
    association :organization
    content { Faker::Lorem.sentence }

    trait :deleted do
      deleted    { true }
      deleted_at { 10.minutes.ago }
    end
  end
end
