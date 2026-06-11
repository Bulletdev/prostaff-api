# frozen_string_literal: true

FactoryBot.define do
  factory :expense do
    association :organization
    association :created_by, factory: :user

    category     { 'travel' }
    description  { 'Team travel expense' }
    amount       { 1000.00 }
    expense_date { Date.current }
    status       { 'pending' }

    trait :paid do
      status { 'paid' }
    end

    trait :approved do
      status { 'approved' }
    end

    trait :rejected do
      status { 'rejected' }
    end

    trait :salary do
      category { 'salary' }
    end

    trait :bonus do
      category { 'bonus' }
    end

    trait :bootcamp do
      category { 'bootcamp' }
    end
  end
end
