# frozen_string_literal: true

require 'rails_helper'

# Multi-tenancy isolation tests
#
# Each example proves that Organization B cannot read, update, or delete
# data that belongs to Organization A, even with a valid JWT.
#
# Pattern: create a resource owned by org_a, authenticate as org_b, assert
# the resource is invisible or inaccessible.
RSpec.describe 'Multi-tenancy isolation', type: :request do
  let!(:org_a)    { create(:organization) }
  let!(:user_a)   { create(:user, :admin, organization: org_a) }

  let!(:org_b)    { create(:organization) }
  let!(:user_b)   { create(:user, :admin, organization: org_b) }

  # ---------------------------------------------------------------------------
  # Players
  # ---------------------------------------------------------------------------

  describe 'Players' do
    let!(:player_a) { create(:player, organization: org_a) }

    it 'does not list org_a players when authenticated as org_b' do
      get '/api/v1/players', headers: auth_headers(user_b)
      expect(response).to have_http_status(:ok)
      ids = json_response.dig(:data, :players)&.map { |p| p[:id] } || []
      expect(ids).not_to include(player_a.id)
    end

    it 'returns 404 when org_b tries to show org_a player' do
      get "/api/v1/players/#{player_a.id}", headers: auth_headers(user_b)
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 when org_b tries to update org_a player' do
      patch "/api/v1/players/#{player_a.id}",
            params: { player: { summoner_name: 'Hacked' } }.to_json,
            headers: auth_headers(user_b)
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 when org_b tries to delete org_a player' do
      delete "/api/v1/players/#{player_a.id}", headers: auth_headers(user_b)
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 when org_b tries to get org_a player stats' do
      get "/api/v1/players/#{player_a.id}/stats", headers: auth_headers(user_b)
      expect(response).to have_http_status(:not_found)
    end
  end

  # ---------------------------------------------------------------------------
  # Matches
  # ---------------------------------------------------------------------------

  describe 'Matches' do
    let!(:match_a) { create(:match, organization: org_a) }

    it 'does not list org_a matches when authenticated as org_b' do
      get '/api/v1/matches', headers: auth_headers(user_b)
      expect(response).to have_http_status(:ok)
      ids = json_response.dig(:data, :matches)&.map { |m| m[:id] } || []
      expect(ids).not_to include(match_a.id)
    end

    it 'returns 404 when org_b tries to show org_a match' do
      get "/api/v1/matches/#{match_a.id}", headers: auth_headers(user_b)
      expect(response).to have_http_status(:not_found)
    end
  end

  # ---------------------------------------------------------------------------
  # VOD Reviews
  # ---------------------------------------------------------------------------

  describe 'VOD Reviews' do
    let!(:vod_a) { create(:vod_review, organization: org_a, reviewer: user_a) }

    it 'does not list org_a vod reviews when authenticated as org_b' do
      get '/api/v1/vod-reviews', headers: auth_headers(user_b)
      expect(response).to have_http_status(:ok)
      ids = json_response.dig(:data, :vod_reviews)&.map { |v| v[:id] } || []
      expect(ids).not_to include(vod_a.id)
    end

    it 'returns 404 when org_b tries to show org_a vod review' do
      get "/api/v1/vod-reviews/#{vod_a.id}", headers: auth_headers(user_b)
      expect(response).to have_http_status(:not_found)
    end
  end

  # ---------------------------------------------------------------------------
  # Team Goals
  # ---------------------------------------------------------------------------

  describe 'Team Goals' do
    let!(:goal_a) { create(:team_goal, organization: org_a) }

    it 'does not list org_a team goals when authenticated as org_b' do
      get '/api/v1/team-goals', headers: auth_headers(user_b)
      expect(response).to have_http_status(:ok)
      ids = json_response.dig(:data, :team_goals)&.map { |g| g[:id] } || []
      expect(ids).not_to include(goal_a.id)
    end

    it 'returns 404 when org_b tries to show org_a team goal' do
      get "/api/v1/team-goals/#{goal_a.id}", headers: auth_headers(user_b)
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 when org_b tries to update org_a team goal' do
      patch "/api/v1/team-goals/#{goal_a.id}",
            params: { team_goal: { title: 'Hijacked' } }.to_json,
            headers: auth_headers(user_b)
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 when org_b tries to delete org_a team goal' do
      delete "/api/v1/team-goals/#{goal_a.id}", headers: auth_headers(user_b)
      expect(response).to have_http_status(:not_found)
    end
  end

  # ---------------------------------------------------------------------------
  # Schedules
  # ---------------------------------------------------------------------------

  describe 'Schedules' do
    let!(:schedule_a) { create(:schedule, organization: org_a) }

    it 'does not list org_a schedules when authenticated as org_b' do
      get '/api/v1/schedules', headers: auth_headers(user_b)
      expect(response).to have_http_status(:ok)
      ids = json_response.dig(:data, :schedules)&.map { |s| s[:id] } || []
      expect(ids).not_to include(schedule_a.id)
    end

    it 'returns 404 when org_b tries to show org_a schedule' do
      get "/api/v1/schedules/#{schedule_a.id}", headers: auth_headers(user_b)
      expect(response).to have_http_status(:not_found)
    end
  end

  # ---------------------------------------------------------------------------
  # Scrims
  # ---------------------------------------------------------------------------

  describe 'Scrims' do
    let!(:scrim_a) { create(:scrim, organization: org_a) }

    it 'does not list org_a scrims when authenticated as org_b' do
      get '/api/v1/scrims/scrims', headers: auth_headers(user_b)
      expect(response).to have_http_status(:ok)
      ids = json_response.dig(:data, :scrims)&.map { |s| s[:id] } || []
      expect(ids).not_to include(scrim_a.id)
    end

    it 'returns 404 when org_b tries to show org_a scrim' do
      get "/api/v1/scrims/scrims/#{scrim_a.id}", headers: auth_headers(user_b)
      expect(response).to have_http_status(:not_found)
    end
  end

  # ---------------------------------------------------------------------------
  # Competitive Matches
  # ---------------------------------------------------------------------------

  describe 'Competitive Matches' do
    let!(:comp_match_a) { create(:competitive_match, organization: org_a) }

    it 'does not list org_a competitive matches when authenticated as org_b' do
      get '/api/v1/competitive/pro-matches', headers: auth_headers(user_b)
      expect(response).to have_http_status(:ok)
      ids = json_response.dig(:data, :matches)&.map { |m| m[:id] } || []
      expect(ids).not_to include(comp_match_a.id)
    end

    it 'returns 404 when org_b tries to show org_a competitive match' do
      get "/api/v1/competitive/pro-matches/#{comp_match_a.id}", headers: auth_headers(user_b)
      expect(response).to have_http_status(:not_found)
    end
  end

  # ---------------------------------------------------------------------------
  # Scouting
  # ---------------------------------------------------------------------------

  describe 'Scouting Watchlist' do
    let!(:target_a)    { create(:scouting_target) }
    let!(:watchlist_a) { create(:scouting_watchlist, organization: org_a, scouting_target: target_a) }

    it 'does not list org_a watchlist entries when authenticated as org_b' do
      get '/api/v1/scouting/watchlist', headers: auth_headers(user_b)
      expect(response).to have_http_status(:ok)
      ids = json_response.dig(:data, :watchlist)&.map { |w| w[:id] } || []
      expect(ids).not_to include(watchlist_a.id)
    end
  end

  # ---------------------------------------------------------------------------
  # Analytics — competitive data scoped to organization
  # ---------------------------------------------------------------------------

  describe 'Analytics — competitive draft-performance' do
    let!(:comp_match_a) { create(:competitive_match, organization: org_a) }

    it 'returns empty data when org_b has no competitive matches' do
      get '/api/v1/analytics/competitive/draft-performance', headers: auth_headers(user_b)
      expect(response).to have_http_status(:ok)
      data = json_response[:data]
      expect(data[:total_matches]).to eq(0)
    end
  end

  # ---------------------------------------------------------------------------
  # Messages
  # ---------------------------------------------------------------------------

  describe 'Messages' do
    let!(:user_b2)  { create(:user, :admin, organization: org_b) }
    let!(:msg_a)    { create(:message, organization: org_a, user: user_a) }

    # Messages endpoint requires recipient_id — use another org_b user as recipient
    it 'does not list org_a messages when authenticated as org_b' do
      get '/api/v1/messages', params: { recipient_id: user_b2.id }, headers: auth_headers(user_b)
      expect(response).to have_http_status(:ok)
      ids = json_response.dig(:data, :messages)&.map { |m| m[:id] } || []
      expect(ids).not_to include(msg_a.id)
    end
  end

  # ---------------------------------------------------------------------------
  # Meta Intelligence Builds
  # ---------------------------------------------------------------------------

  describe 'Meta Intelligence Builds' do
    let!(:build_a) do
      create(:saved_build, organization: org_a, champion: 'Jinx', role: 'adc')
    end

    it 'does not list org_a builds when authenticated as org_b' do
      get '/api/v1/meta/builds', headers: auth_headers(user_b)
      expect(response).to have_http_status(:ok)
      ids = json_response.dig(:data, :builds)&.map { |b| b[:id] } || []
      expect(ids).not_to include(build_a.id)
    end

    it 'returns 404 when org_b tries to show org_a build' do
      get "/api/v1/meta/builds/#{build_a.id}", headers: auth_headers(user_b)
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 when org_b tries to update org_a build' do
      patch "/api/v1/meta/builds/#{build_a.id}",
            params: { build: { title: 'Stolen' } }.to_json,
            headers: auth_headers(user_b)
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 when org_b tries to delete org_a build' do
      delete "/api/v1/meta/builds/#{build_a.id}", headers: auth_headers(user_b)
      expect(response).to have_http_status(:not_found)
    end
  end
end
