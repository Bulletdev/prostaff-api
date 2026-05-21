# frozen_string_literal: true

FactoryBot.define do
  factory :tournament do
    sequence(:name) { |n| "ArenaBR Season #{n}" }
    game            { 'league_of_legends' }
    format          { 'double_elimination' }
    status          { 'registration_open' }
    max_teams       { 16 }
    entry_fee_cents { 10_000 }
    prize_pool_cents { 128_000 }
    bo_format { 3 }
    scheduled_start_at { 7.days.from_now }

    trait :draft do
      status { 'draft' }
    end

    trait :in_progress do
      status { 'in_progress' }
    end

    trait :finished do
      status { 'finished' }
      finished_at { Time.current }
    end

    trait :free do
      entry_fee_cents { 0 }
      prize_pool_cents { 0 }
    end
  end

  factory :tournament_team do
    association :tournament
    association :organization
    sequence(:team_name) { |n| "Team #{n}" }
    sequence(:team_tag)  { |n| "T#{n.to_s.rjust(2, '0')}" }
    status { 'pending' }

    trait :approved do
      status { 'approved' }
      approved_at { Time.current }
    end

    trait :rejected do
      status { 'rejected' }
      rejected_at { Time.current }
    end
  end

  factory :tournament_match do
    association :tournament
    bracket_side  { 'upper' }
    round_label   { 'UB Round 1' }
    round_order   { 1 }
    match_number  { 1 }
    bo_format     { 3 }
    status        { 'scheduled' }

    trait :checkin_open do
      status { 'checkin_open' }
      checkin_deadline_at { 10.minutes.from_now }
      wo_deadline_at      { 25.minutes.from_now }
    end

    trait :in_progress do
      status     { 'in_progress' }
      started_at { Time.current }
    end

    trait :awaiting_report do
      status { 'awaiting_report' }
    end

    trait :disputed do
      status { 'disputed' }
    end

    trait :completed do
      status       { 'completed' }
      completed_at { Time.current }
    end
  end

  factory :match_report do
    association :tournament_match
    association :tournament_team
    team_a_score { 2 }
    team_b_score { 1 }
    evidence_url { 'https://example.com/screenshot.png' }
    status       { 'submitted' }
    submitted_at { Time.current }
    deadline_at  { 2.hours.from_now }
  end

  factory :team_checkin do
    association :tournament_match
    association :tournament_team
    checked_in_at { Time.current }
  end

  factory :tournament_roster_snapshot do
    association :tournament_team
    association :player
    sequence(:summoner_name) { |n| "Player#{n}" }
    role     { 'mid' }
    position { 'starter' }
    locked_at { Time.current }
  end
end
