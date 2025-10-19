FactoryBot.define do
  factory :user do
    association :organization
    email { Faker::Internet.email }
    password { 'password123' }
    password_confirmation { 'password123' }
    full_name { Faker::Name.name }
    role { 'analyst' }

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
