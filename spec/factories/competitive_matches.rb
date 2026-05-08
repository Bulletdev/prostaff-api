# frozen_string_literal: true

CHAMPION_POOL = ['Jinx', 'Caitlyn', 'Thresh', 'Lulu', 'Azir', 'Viktor', 'Vi', 'Lee Sin', 'Garen', 'Malphite',
                 'Orianna', 'Lissandra', 'Shen', 'Zed', 'Yasuo', 'Syndra', 'Aatrox', 'Graves', 'Nautilus', 'Renekton'].freeze

def random_pick(champion, win: false)
  {
    'champion' => champion,
    'role' => %w[top jungle mid adc support].sample,
    'kills' => rand(0..10),
    'deaths' => rand(0..8),
    'assists' => rand(0..15),
    'cs' => rand(100..350),
    'gold' => rand(8000..18_000),
    'damage' => rand(10_000..60_000),
    'win' => win
  }
end

FactoryBot.define do
  factory :competitive_match do
    association :organization
    tournament_name  { 'Test Tournament' }
    tournament_stage { 'Group Stage' }
    our_team_name    { 'Team A' }
    opponent_team_name { 'Team B' }
    side             { %w[blue red].sample }
    victory          { true }
    match_format     { 'BO1' }

    transient do
      our_champions      { CHAMPION_POOL.sample(5) }
      opponent_champions { (CHAMPION_POOL - our_champions).sample(5) }
    end

    our_picks do
      our_champions.map { |c| random_pick(c, win: victory) }
    end

    opponent_picks do
      opponent_champions.map { |c| random_pick(c, win: !victory) }
    end

    game_stats { { 'win_team' => victory ? our_team_name : opponent_team_name } }
  end
end
