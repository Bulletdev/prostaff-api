# frozen_string_literal: true

FactoryBot.define do
  factory :message do
    association :organization
    association :user
    content { Faker::Lorem.sentence }
    deleted { false }
  end
end
