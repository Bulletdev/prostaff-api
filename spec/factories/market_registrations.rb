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
    solo_queue_id        { nil }
    image_url            { nil }

    trait :free_agent do
      team_name         { nil }
      contract_end_date { 30.days.ago.to_date }
    end

    trait :with_soloqueue do
      solo_queue_id { "#{Faker::Internet.username(specifier: 4..10)}#BR1" }
    end

    trait :expiring_soon do
      contract_end_date { 10.days.from_now.to_date }
    end

    trait :no_contract do
      contract_end_date { nil }
    end
  end
end
