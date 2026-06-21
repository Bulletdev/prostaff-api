# frozen_string_literal: true

FactoryBot.define do
  factory :market_registration do
    player_external_name { Faker::Internet.username(specifier: 5..15) }
    team_name            { Faker::Esport.team }
    region               { 'CBLOL' }
    role                 { %w[top jungle mid adc support].sample }
    residency            { 'BR' }
    contract_end_date    { 6.months.from_now.to_date }
    source               { 'leaguepedia_gcd' }
    snapshot_date        { Date.current }
    raw_payload          { {} }

    trait :expiring_soon do
      contract_end_date { 10.days.from_now.to_date }
    end

    trait :no_contract do
      contract_end_date { nil }
    end
  end
end
