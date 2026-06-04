# frozen_string_literal: true

FactoryBot.define do
  factory :token_blacklist do
    jti        { SecureRandom.uuid }
    expires_at { 1.hour.from_now }

    trait :expired do
      expires_at { 1.hour.ago }
    end
  end
end
