# frozen_string_literal: true

FactoryBot.define do
  factory :player_match_stat do
    association :match
    association :player
    champion   { %w[Jinx Caitlyn Thresh Azir Garen].sample }
    role       { %w[top jungle mid adc support].sample }
    kills      { rand(0..15) }
    deaths     { rand(0..10) }
    assists    { rand(0..20) }
    cs         { rand(100..350) }
    vision_score { rand(10..80) }
    damage_dealt_champions { rand(10_000..60_000) }
    gold_earned { rand(8_000..18_000) }
  end
end
