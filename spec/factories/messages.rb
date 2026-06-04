# frozen_string_literal: true

FactoryBot.define do
  factory :message do
    association :organization

    # user_id stores the sender UUID. The FK to users was removed to support
    # both User and Player senders. We create a User and assign its id.
    transient do
      sender { nil }
    end

    after(:build) do |message, evaluator|
      if evaluator.sender
        message.user_id = evaluator.sender.id
      elsif message.user_id.blank?
        org = message.organization || create(:organization)
        message.organization ||= org
        user = create(:user, organization: org)
        message.user_id = user.id
      end
    end

    content { Faker::Lorem.sentence }
    deleted { false }
    sender_type { 'User' }
    recipient_type { 'User' }
  end
end
