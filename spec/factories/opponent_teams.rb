# frozen_string_literal: true

FactoryBot.define do
  factory :opponent_team do
    name { Faker::Esport.team }
    region { 'BR' }
    tier { 'tier_1' }
  end
end
