# frozen_string_literal: true

FactoryBot.define do
  factory :ai_champion_matrix do
    champion_a  { 'Jinx' }
    champion_b  { 'Caitlyn' }
    wins_a      { 7 }
    total_games { 10 }
  end
end
