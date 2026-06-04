# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Team Goals API', type: :request do
  let(:organization) { create(:organization) }
  let(:user)         { create(:user, :admin, organization: organization) }

  describe 'GET /api/v1/team-goals' do
    let!(:active_goal)    { create(:team_goal, organization: organization, status: 'active', progress: 50) }
    let!(:completed_goal) { create(:team_goal, :completed, organization: organization) }

    context 'when authenticated' do
      it 'returns 200 with all goals for the organization' do
        get '/api/v1/team-goals', headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:goals].size).to eq(2)
      end

      it 'includes pagination metadata' do
        get '/api/v1/team-goals', headers: auth_headers(user)

        expect(json_response[:data][:pagination]).to include(
          :current_page,
          :per_page,
          :total_pages,
          :total_count
        )
      end

      it 'returns progress_percentage between 0 and 100 for each goal' do
        get '/api/v1/team-goals', headers: auth_headers(user)

        goals = json_response[:data][:goals]
        goals.each do |g|
          progress = g[:progress].to_f
          expect(progress).to be >= 0
          expect(progress).to be <= 100
        end
      end

      it 'includes a summary with active_count and completed_count' do
        get '/api/v1/team-goals', headers: auth_headers(user)

        summary = json_response[:data][:summary]
        expect(summary[:active_count]).to eq(1)
        expect(summary[:completed_count]).to eq(1)
      end

      it 'filters by status=active' do
        get '/api/v1/team-goals', params: { status: 'active' }, headers: auth_headers(user)

        expect(json_response[:data][:goals].size).to eq(1)
        expect(json_response[:data][:goals][0][:status]).to eq('active')
      end

      it 'filters only active goals via active=true' do
        get '/api/v1/team-goals', params: { active: 'true' }, headers: auth_headers(user)

        goals = json_response[:data][:goals]
        expect(goals.size).to eq(1)
        goals.each { |g| expect(g[:status]).to eq('active') }
      end

      it 'filters team goals (no player) via type=team' do
        player     = create(:player, organization: organization)
        player_goal = create(:team_goal, :for_player, organization: organization,
                             player: player, status: 'active')

        get '/api/v1/team-goals', params: { type: 'team' }, headers: auth_headers(user)

        ids = json_response[:data][:goals].map { |g| g[:id] }
        expect(ids).not_to include(player_goal.id)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/team-goals'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'cross-organization isolation' do
      let(:other_org)  { create(:organization) }
      let(:other_user) { create(:user, :admin, organization: other_org) }

      it 'does not return goals from another organization' do
        get '/api/v1/team-goals', headers: auth_headers(other_user)

        expect(json_response[:data][:goals]).to be_empty
      end
    end
  end

  describe 'POST /api/v1/team-goals' do
    let(:valid_params) do
      {
        team_goal: {
          title: 'Reach 65% Win Rate',
          category: 'performance',
          metric_type: 'win_rate',
          target_value: 65.0,
          current_value: 52.0,
          start_date: Date.current.iso8601,
          end_date: (Date.current + 30.days).iso8601,
          status: 'active',
          progress: 0
        }
      }
    end

    context 'when authenticated as admin' do
      it 'creates the goal and returns 201' do
        post '/api/v1/team-goals', params: valid_params.to_json, headers: auth_headers(user)

        expect(response).to have_http_status(:created)
        expect(json_response[:data][:goal][:title]).to eq('Reach 65% Win Rate')
      end

      it 'returns progress between 0 and 100 on the created goal' do
        post '/api/v1/team-goals', params: valid_params.to_json, headers: auth_headers(user)

        progress = json_response[:data][:goal][:progress].to_f
        expect(progress).to be >= 0
        expect(progress).to be <= 100
      end

      it 'rejects end_date before start_date with 422' do
        params = valid_params.deep_merge(
          team_goal: {
            end_date: (Date.current - 1.day).iso8601
          }
        )

        post '/api/v1/team-goals', params: params.to_json, headers: auth_headers(user)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'rejects invalid metric_type with 422' do
        params = valid_params.deep_merge(team_goal: { metric_type: 'invalid_metric' })

        post '/api/v1/team-goals', params: params.to_json, headers: auth_headers(user)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401 when content-type is set but no auth token' do
        post '/api/v1/team-goals',
             params: valid_params.to_json,
             headers: { 'Content-Type' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/team-goals/:id' do
    let(:goal) { create(:team_goal, organization: organization) }

    context 'when authenticated' do
      it 'returns the goal with progress in [0, 100]' do
        get "/api/v1/team-goals/#{goal.id}", headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        progress = json_response[:data][:goal][:progress].to_f
        expect(progress).to be >= 0
        expect(progress).to be <= 100
      end
    end

    context 'when accessing another org goal' do
      let(:other_org)  { create(:organization) }
      let(:other_user) { create(:user, :admin, organization: other_org) }

      it 'returns 404' do
        get "/api/v1/team-goals/#{goal.id}", headers: auth_headers(other_user)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        get "/api/v1/team-goals/#{goal.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH /api/v1/team-goals/:id' do
    let(:goal) { create(:team_goal, organization: organization, current_value: 52.0, target_value: 65.0) }

    context 'when authenticated as admin' do
      it 'updates the goal and returns 200' do
        patch "/api/v1/team-goals/#{goal.id}",
              params: { team_goal: { current_value: 60.0 } }.to_json,
              headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        updated_progress = json_response[:data][:goal][:progress].to_f
        expect(updated_progress).to be >= 0
        expect(updated_progress).to be <= 100
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        patch "/api/v1/team-goals/#{goal.id}", params: {}.to_json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/team-goals/:id' do
    let!(:goal) { create(:team_goal, organization: organization) }

    context 'when authenticated as admin' do
      it 'deletes the goal and returns 200' do
        delete "/api/v1/team-goals/#{goal.id}", headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        expect { TeamGoal.find(goal.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        delete "/api/v1/team-goals/#{goal.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
