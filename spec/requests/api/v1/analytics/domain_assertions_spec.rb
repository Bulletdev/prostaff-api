# frozen_string_literal: true

require 'rails_helper'

# Domain assertions for analytics endpoints.
# Validates LoL-specific invariants that must hold regardless of data volume:
#   - KDA >= 0 (handles deaths == 0 without division-by-zero)
#   - win_rate always in [0, 100]
#   - pick_rate always in [0, 100]
#   - roles only in %w[top jungle mid adc support]
#   - game stats are non-negative integers
RSpec.describe 'Analytics Domain Assertions', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, organization: organization) }

  let(:players) do
    %w[top jungle mid adc support].map do |role|
      create(:player, organization: organization, role: role)
    end
  end

  # Create matches with player stats covering edge cases:
  # - a game where all deaths = 0 (tests KDA denominator guard)
  # - a game where all kills = 0 (tests 0 KDA)
  # - wins and losses (tests win_rate bounds)
  let!(:match_with_zero_deaths) do
    m = create(:match, organization: organization, victory: true)
    players.each do |player|
      create(:player_match_stat,
             match: m,
             player: player,
             kills: 5,
             deaths: 0,
             assists: 10,
             role: player.role)
    end
    m
  end

  let!(:match_with_zero_kills) do
    m = create(:match, organization: organization, victory: false)
    players.each do |player|
      create(:player_match_stat,
             match: m,
             player: player,
             kills: 0,
             deaths: 5,
             assists: 0,
             role: player.role)
    end
    m
  end

  let!(:normal_match) do
    m = create(:match, organization: organization, victory: true)
    players.each do |player|
      create(:player_match_stat,
             match: m,
             player: player,
             kills: rand(3..8),
             deaths: rand(1..5),
             assists: rand(5..12),
             role: player.role)
    end
    m
  end

  describe 'GET /api/v1/analytics/performance' do
    it 'returns win_rate within [0, 100]' do
      get '/api/v1/analytics/performance', headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      data = json_response.dig(:data, :overview)
      expect(data[:win_rate]).to be_between(0, 100)
    end

    it 'returns avg_kda >= 0 even with zero-death games' do
      get '/api/v1/analytics/performance', headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      data = json_response.dig(:data, :overview)
      expect(data[:avg_kda]).to be >= 0
    end

    it 'returns non-negative kill/death/assist averages' do
      get '/api/v1/analytics/performance', headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      data = json_response.dig(:data, :overview)
      expect(data[:avg_kills_per_game]).to be >= 0
      expect(data[:avg_deaths_per_game]).to be >= 0
      expect(data[:avg_assists_per_game]).to be >= 0
    end

    it 'returns total_matches equal to created match count' do
      get '/api/v1/analytics/performance', headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      data = json_response.dig(:data, :overview)
      expect(data[:total_matches]).to eq(3)
    end

    it 'returns wins + losses == total_matches' do
      get '/api/v1/analytics/performance', headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      data = json_response.dig(:data, :overview)
      expect(data[:wins] + data[:losses]).to eq(data[:total_matches])
    end
  end

  describe 'GET /api/v1/analytics/team-comparison' do
    it 'returns KDA >= 0 for each player including zero-death scenarios' do
      get '/api/v1/analytics/team-comparison', headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      player_stats = json_response.dig(:data, :players)
      player_stats.each do |stat|
        expect(stat[:kda]).to be >= 0,
          "expected KDA >= 0 but got #{stat[:kda]} for player #{stat.dig(:player, :summoner_name)}"
      end
    end

    it 'returns only valid LoL roles in role_rankings' do
      valid_roles = %w[top jungle mid adc support]

      get '/api/v1/analytics/team-comparison', headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      role_rankings = json_response.dig(:data, :role_rankings)
      role_rankings.keys.map(&:to_s).each do |role|
        expect(valid_roles).to include(role),
          "unexpected role '#{role}' in role_rankings"
      end
    end
  end

  describe 'GET /api/v1/analytics/champions/:player_id' do
    let(:player) { players.first }

    it 'returns win_rate within [0, 100] for each champion' do
      get "/api/v1/analytics/champions/#{player.id}", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      champ_stats = json_response.dig(:data, :champion_stats)
      champ_stats.each do |cs|
        expect(cs[:win_rate]).to be_between(0, 100),
          "win_rate #{cs[:win_rate]} out of bounds for champion #{cs[:champion]}"
      end
    end

    it 'returns avg_kda >= 0 for each champion' do
      get "/api/v1/analytics/champions/#{player.id}", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      champ_stats = json_response.dig(:data, :champion_stats)
      champ_stats.each do |cs|
        expect(cs[:avg_kda]).to be >= 0,
          "avg_kda #{cs[:avg_kda]} is negative for champion #{cs[:champion]}"
      end
    end

    it 'returns only valid mastery grades' do
      valid_grades = %w[S A B C D]

      get "/api/v1/analytics/champions/#{player.id}", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      champ_stats = json_response.dig(:data, :champion_stats)
      champ_stats.each do |cs|
        expect(valid_grades).to include(cs[:mastery_grade]) if cs[:mastery_grade].present?
      end
    end
  end

  describe 'GET /api/v1/analytics/kda-trend/:player_id' do
    let(:player) { players.first }

    it 'returns KDA >= 0 for every match in the trend' do
      get "/api/v1/analytics/kda-trend/#{player.id}", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      trend = json_response.dig(:data, :kda_trend) || []
      trend.each do |point|
        expect(point[:kda]).to be >= 0,
          "KDA #{point[:kda]} is negative in trend"
      end
    end
  end

  describe 'GET /api/v1/players/:id/stats' do
    let(:player) { players.first }

    it 'returns win_rate within [0, 100]' do
      get "/api/v1/players/#{player.id}/stats", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      stats = json_response.dig(:data, :overall)
      expect(stats[:win_rate]).to be_between(0, 100)
    end

    it 'returns avg_kda >= 0 with zero-death games present' do
      get "/api/v1/players/#{player.id}/stats", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      stats = json_response.dig(:data, :overall)
      expect(stats[:avg_kda]).to be >= 0
    end

    it 'returns role within valid LoL roles' do
      valid_roles = %w[top jungle mid adc support]

      get "/api/v1/players/#{player.id}/stats", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      returned_role = json_response.dig(:data, :player, :role)
      expect(valid_roles).to include(returned_role) if returned_role.present?
    end

    it 'filters by invalid role returns 422 or empty result' do
      get '/api/v1/players', params: { role: 'carry' }, headers: auth_headers(user)

      # Either the API rejects the invalid role or returns an empty list — never a list with carry players
      if response.status == 422
        expect(json_response.dig(:error, :code)).to be_present
      else
        expect(response).to have_http_status(:ok)
        player_roles = json_response.dig(:data, :players).map { |p| p[:role] }
        expect(player_roles).not_to include('carry')
      end
    end
  end
end
