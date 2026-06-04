# frozen_string_literal: true

FactoryBot.define do
  factory :scrim_request do
    association :requesting_organization, factory: :organization
    association :target_organization, factory: :organization
    status { 'pending' }
    game { 'league_of_legends' }
    message { Faker::Lorem.sentence }
    proposed_at { 1.hour.from_now }
    expires_at { 3.days.from_now }
    games_planned { 3 }

    trait :pending do
      status { 'pending' }
    end

    trait :accepted do
      status { 'accepted' }
    end

    trait :rejected do
      status { 'rejected' }
    end

    trait :expired do
      status { 'pending' }
      expires_at { 1.day.ago }
    end
  end
end
