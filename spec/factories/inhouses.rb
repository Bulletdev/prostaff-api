# frozen_string_literal: true

FactoryBot.define do
  factory :inhouse do
    association :organization
    association :created_by, factory: :user
    status { 'waiting' }
    games_played { 0 }
    blue_wins { 0 }
    red_wins { 0 }
    formation_mode { 'auto' }

    trait :waiting do
      status { 'waiting' }
    end

    trait :in_progress do
      status { 'in_progress' }
    end

    trait :done do
      status { 'done' }
      games_played { 3 }
      blue_wins { 2 }
      red_wins { 1 }
    end

    trait :auto do
      formation_mode { 'auto' }
    end

    trait :captain_draft do
      formation_mode { 'captain_draft' }
    end
  end

  factory :inhouse_queue do
    association :organization
    association :created_by, factory: :user
    status { 'open' }
    check_in_deadline { 30.minutes.from_now }

    trait :open do
      status { 'open' }
    end

    trait :closed do
      status { 'closed' }
      check_in_deadline { 10.minutes.ago }
    end
  end

  factory :inhouse_queue_entry do
    association :inhouse_queue
    association :player
    role { %w[top jungle mid adc support].sample }
    tier_snapshot { %w[DIAMOND MASTER GRANDMASTER CHALLENGER].sample }
    checked_in { false }

    trait :checked_in do
      checked_in { true }
      checked_in_at { Time.current }
    end
  end

  factory :inhouse_participation do
    association :inhouse
    association :player
    team { 'none' }
    tier_snapshot { %w[DIAMOND MASTER GRANDMASTER CHALLENGER].sample }
    is_captain { false }
    role { %w[top jungle mid adc support].sample }
    mu_snapshot { 25.0 }
    sigma_snapshot { 8.333333333333334 }
    wins { 0 }
    losses { 0 }

    trait :blue_team do
      team { 'blue' }
    end

    trait :red_team do
      team { 'red' }
    end

    trait :captain do
      is_captain { true }
    end
  end

  factory :player_inhouse_rating do
    association :player
    association :organization
    role { %w[top jungle mid adc support].sample }
    mu { 25.0 }
    sigma { 8.333333333333334 }
    games_played { 0 }
    wins { 0 }
    losses { 0 }

    trait :experienced do
      games_played { 50 }
      wins { 30 }
      losses { 20 }
      mu { 28.5 }
      sigma { 3.2 }
    end
  end
end
