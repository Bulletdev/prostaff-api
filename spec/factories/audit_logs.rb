# frozen_string_literal: true

FactoryBot.define do
  factory :audit_log do
    association :organization
    association :user
    action { %w[create update destroy login logout].sample }
    entity_type { %w[Player Match Scrim User Organization].sample }
    entity_id { SecureRandom.uuid }
    old_values { nil }
    new_values { { 'status' => 'active' } }
    ip_address { Faker::Internet.ip_v4_address }
    user_agent { Faker::Internet.user_agent }

    trait :create_action do
      action { 'create' }
      old_values { nil }
      new_values { { 'status' => 'active', 'name' => Faker::Name.name } }
    end

    trait :update_action do
      action { 'update' }
      old_values { { 'status' => 'inactive' } }
      new_values { { 'status' => 'active' } }
    end

    trait :destroy_action do
      action { 'destroy' }
      old_values { { 'status' => 'active' } }
      new_values { nil }
    end

    trait :login_action do
      action { 'login' }
      entity_type { 'User' }
      old_values { nil }
      new_values { nil }
    end
  end
end
