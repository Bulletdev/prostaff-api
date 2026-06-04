# frozen_string_literal: true

FactoryBot.define do
  factory :feedback do
    association :user
    association :organization
    category { %w[bug feature improvement other].sample }
    title { Faker::Lorem.sentence(word_count: 5) }
    description { Faker::Lorem.paragraph }
    rating { rand(1..5) }
    status { 'open' }
    votes_count { 0 }
    source { 'prostaff' }

    trait :open do
      status { 'open' }
    end

    trait :in_progress do
      status { 'in_progress' }
    end

    trait :resolved do
      status { 'resolved' }
    end

    trait :closed do
      status { 'closed' }
    end

    trait :bug do
      category { 'bug' }
    end

    trait :feature do
      category { 'feature' }
    end

    trait :highly_voted do
      votes_count { rand(50..200) }
    end
  end

  factory :feedback_vote do
    association :feedback
    association :user
  end
end
