# frozen_string_literal: true

FactoryBot.define do
  factory :password_reset_token do
    association :user
    expires_at { 1.hour.from_now }
    # token and expires_at are set by before_validation callbacks

    trait :expired do
      expires_at { 1.hour.ago }
    end

    trait :used do
      used_at { 30.minutes.ago }
    end

    trait :for_player do
      user { nil }
      association :player
    end
  end
end
