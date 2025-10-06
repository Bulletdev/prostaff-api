FactoryBot.define do
  factory :organization do
    name { Faker::Esport.team }
    slug { name.parameterize }
    region { %w[BR NA EUW KR].sample }
    tier { %w[amateur semi_pro professional].sample }
    primary_color { Faker::Color.hex_color }
    secondary_color { Faker::Color.hex_color }
    logo_url { Faker::Internet.url }
    website_url { Faker::Internet.url }
  end
end
