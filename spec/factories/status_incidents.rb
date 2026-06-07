# frozen_string_literal: true

FactoryBot.define do
  factory :status_incident do
    association :created_by_user, factory: :user
    title { Faker::Lorem.sentence(word_count: 6) }
    body { Faker::Lorem.paragraph }
    severity { 'minor' }
    status { 'investigating' }
    affected_components { %w[api database] }
    started_at { 30.minutes.ago }
    resolved_at { nil }

    trait :minor do
      severity { 'minor' }
    end

    trait :major do
      severity { 'major' }
    end

    trait :critical do
      severity { 'critical' }
    end

    trait :investigating do
      status { 'investigating' }
    end

    trait :identified do
      status { 'identified' }
    end

    trait :monitoring do
      status { 'monitoring' }
    end

    trait :resolved do
      status { 'resolved' }
      resolved_at { Time.current }
    end
  end

  factory :status_incident_update do
    association :status_incident
    association :created_by_user, factory: :user
    status { 'investigating' }
    body { Faker::Lorem.paragraph }
  end
end
