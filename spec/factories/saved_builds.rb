# frozen_string_literal: true

FactoryBot.define do
  factory :saved_build do
    association :organization
    champion    { %w[Jinx Caitlyn Thresh Azir Garen].sample }
    role        { %w[top jungle mid adc support].sample }
    data_source { 'manual' }
    games_played { rand(0..200) }
    win_rate    { rand(0.0..100.0).round(2) }
    patch_version { "14.#{rand(1..24)}" }
    items       { [3153, 3006, 3031, 3036, 3072] }
    is_public   { false }

    trait :aggregated do
      data_source { 'aggregated' }
      games_played { rand(20..500) }
    end

    trait :with_sufficient_sample do
      games_played { 20 }
    end

    trait :jinx_adc do
      champion { 'Jinx' }
      role     { 'adc' }
    end
  end
end
