# frozen_string_literal: true

FactoryBot.define do
  factory :scouting_watchlist do
    association :organization
    association :scouting_target
    association :added_by, factory: :user
  end
end
