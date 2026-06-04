# frozen_string_literal: true

FactoryBot.define do
  factory :availability_window do
    association :organization
    day_of_week { rand(0..6) }
    start_hour { 18 }
    end_hour { 22 }
    timezone { 'America/Sao_Paulo' }
    game { 'league_of_legends' }
    region { %w[BR NA EUW KR].sample }
    tier_preference { 'any' }
    active { true }

    trait :inactive do
      active { false }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :weekend do
      day_of_week { [0, 6].sample }
    end

    trait :weekday do
      day_of_week { rand(1..5) }
    end
  end
end
