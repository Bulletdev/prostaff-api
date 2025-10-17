FactoryBot.define do
  factory :organization do
    name { Faker::Esport.team }
    slug { name.parameterize }
    region { %w[BR NA EUW KR].sample }
    tier { %w[amateur semi_pro professional].sample }
  end
end
