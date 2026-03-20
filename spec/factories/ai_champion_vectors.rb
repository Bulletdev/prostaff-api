# frozen_string_literal: true

FactoryBot.define do
  factory :ai_champion_vector do
    champion_name { 'Jinx' }
    vector_data   { [0.6, 0.5, 0.3, 0.25, 0.7] }
    games_count   { 20 }
  end
end
