# frozen_string_literal: true

FactoryBot.define do
  factory :scouting_target do
    summoner_name { Faker::Internet.username(specifier: 5..15) }
    region        { 'BR' }
    role          { %w[top jungle mid adc support].sample }
    current_tier  { 'DIAMOND' }
    current_rank  { 'II' }
    current_lp    { rand(0..99) }
    status        { 'watching' }
    champion_pool { %w[Jinx Caitlyn Thresh Lulu Azir].sample(3) }
  end
end
