FactoryBot.define do
  factory :player do
    association :organization
    summoner_name { Faker::Esport.player }
    real_name { Faker::Name.name }
    role { %w[top jungle mid adc support].sample }
    status { 'active' }
    jersey_number { rand(1..99) }
    birth_date { Faker::Date.birthday(min_age: 18, max_age: 30) }
    country { 'BR' }
    nationality { 'Brazilian' }
    solo_queue_tier { %w[DIAMOND MASTER GRANDMASTER CHALLENGER].sample }
    solo_queue_rank { %w[I II III IV].sample }
    solo_queue_lp { rand(0..100) }
    solo_queue_wins { rand(50..500) }
    solo_queue_losses { rand(50..500) }
  end
end
