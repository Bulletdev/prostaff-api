# frozen_string_literal: true

FactoryBot.define do
  factory :draft_plan do
    association :organization
    association :created_by, factory: :user
    association :updated_by, factory: :user
    opponent_team { Faker::Esport.team }
    side { %w[blue red].sample }
    patch_version { "14.#{rand(1..24)}" }
    our_bans { %w[Jinx Thresh Leblanc] }
    opponent_bans { %w[Garen Yasuo Zed] }
    priority_picks { { 'mid' => 'Ahri', 'adc' => 'Caitlyn' } }
    if_then_scenarios { [] }
    is_active { true }

    trait :inactive do
      is_active { false }
    end

    trait :with_scenarios do
      if_then_scenarios do
        [
          { 'trigger' => 'enemy_bans_jinx', 'action' => 'pick_caitlyn', 'note' => 'fallback adc' }
        ]
      end
    end
  end
end
