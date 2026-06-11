# frozen_string_literal: true

FactoryBot.define do
  factory :contract do
    association :organization
    association :player
    association :created_by, factory: :user

    contract_type { 'player' }
    status        { 'draft' }
    start_date    { Date.current }
    end_date      { Date.current + 1.year }
    base_salary   { 5000.00 }
    salary_period { 'monthly' }
    metadata      { {} }

    trait :active do
      status { 'active' }
    end

    trait :draft do
      status { 'draft' }
    end

    trait :expired do
      status     { 'expired' }
      start_date { 2.years.ago }
      end_date   { 1.year.ago }
    end

    trait :expiring_soon do
      status   { 'active' }
      end_date { Date.current + 15.days }
    end

    trait :expiring_in_30_days do
      status   { 'active' }
      end_date { Date.current + 30.days }
    end

    trait :weekly_salary do
      salary_period { 'weekly' }
    end

    trait :per_event_salary do
      salary_period { 'per_event' }
    end
  end
end
