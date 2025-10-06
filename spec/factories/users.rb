FactoryBot.define do
  factory :user do
    association :organization
    email { Faker::Internet.email }
    password { 'password123' }
    password_confirmation { 'password123' }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    role { 'analyst' }
    status { 'active' }

    trait :owner do
      role { 'owner' }
    end

    trait :admin do
      role { 'admin' }
    end

    trait :coach do
      role { 'coach' }
    end

    trait :analyst do
      role { 'analyst' }
    end

    trait :viewer do
      role { 'viewer' }
    end
  end
end
