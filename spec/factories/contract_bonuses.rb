# frozen_string_literal: true

FactoryBot.define do
  factory :contract_bonus do
    association :contract
    association :organization

    bonus_type { 'performance' }
    trigger    { 'Win rate >= 60% during the split' }
    amount     { 2000.00 }
    currency   { 'BRL' }
    status     { 'pending' }
  end
end
