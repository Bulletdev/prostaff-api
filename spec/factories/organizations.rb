FactoryBot.define do
  factory :organization do
    name { Faker::Esport.team }
    slug { name.parameterize }
    region { %w[BR NA EUW KR].sample }
    tier { %w[tier_3_amateur tier_2_semi_pro tier_1_professional].sample }
  end
end
