# frozen_string_literal: true

FactoryBot.define do
  factory :support_ticket do
    association :organization
    association :user

    subject { Faker::Lorem.sentence(word_count: 4) }
    description { Faker::Lorem.paragraph(sentence_count: 3) }
    category { 'technical' }
    priority { 'medium' }
    status { 'open' }

    trait :resolved do
      status { 'resolved' }
    end
  end
end
