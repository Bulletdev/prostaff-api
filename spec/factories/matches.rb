FactoryBot.define do
  factory :match do
    association :organization
    match_type { %w[official scrim tournament].sample }
    game_start { Faker::Time.between(from: 30.days.ago, to: Time.current) }
    game_end { game_start + rand(1200..2400).seconds }
    game_duration { (game_end - game_start).to_i }
    victory { [true, false].sample }
    patch_version { "13.#{rand(1..24)}.1" }
    opponent_name { Faker::Esport.team }
    our_side { %w[blue red].sample }
    our_score { rand(5..30) }
    opponent_score { rand(5..30) }
  end
end
