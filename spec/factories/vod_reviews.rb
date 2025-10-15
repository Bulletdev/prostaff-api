FactoryBot.define do
  factory :vod_review do
    association :organization
    association :reviewer, factory: :user
    association :match, factory: :match

    title { Faker::Lorem.sentence(word_count: 3) }
    description { Faker::Lorem.paragraph }
    review_type { %w[team individual opponent].sample }
    review_date { Faker::Time.between(from: 30.days.ago, to: Time.current) }
    video_url { "https://www.youtube.com/watch?v=#{Faker::Alphanumeric.alpha(number: 11)}" }
    thumbnail_url { Faker::Internet.url }
    duration { rand(1800..3600) }
    status { 'draft' }
    is_public { false }
    tags { %w[scrim review analysis].sample(2) }

    trait :published do
      status { 'published' }
    end

    trait :archived do
      status { 'archived' }
    end

    trait :public do
      is_public { true }
      share_link { SecureRandom.urlsafe_base64(16) }
    end

    trait :with_timestamps do
      after(:create) do |vod_review|
        create_list(:vod_timestamp, 3, vod_review: vod_review)
      end
    end
  end
end
