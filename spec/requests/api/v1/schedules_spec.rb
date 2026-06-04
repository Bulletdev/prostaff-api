# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Schedules API', type: :request do
  let(:organization) { create(:organization) }
  let(:user)         { create(:user, :admin, organization: organization) }

  describe 'GET /api/v1/schedules' do
    let!(:future_schedule) { create(:schedule, organization: organization) }
    let!(:past_schedule)   { create(:schedule, :past, organization: organization) }

    context 'when authenticated' do
      it 'returns 200 with all schedules for the organization' do
        get '/api/v1/schedules', headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:schedules].size).to eq(2)
      end

      it 'includes pagination metadata' do
        get '/api/v1/schedules', headers: auth_headers(user)

        expect(json_response[:data][:pagination]).to include(
          :current_page,
          :per_page,
          :total_pages,
          :total_count
        )
      end

      it 'filters by start_date and end_date range' do
        start_date = 1.day.from_now.iso8601
        end_date   = 3.days.from_now.iso8601

        get '/api/v1/schedules', params: { start_date: start_date, end_date: end_date },
                                 headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:schedules].size).to eq(1)
        expect(json_response[:data][:schedules][0][:title]).to eq(future_schedule.title)
      end

      it 'filters upcoming schedules' do
        get '/api/v1/schedules', params: { upcoming: 'true' }, headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:schedules].size).to eq(1)
        expect(json_response[:data][:schedules][0][:title]).to eq(future_schedule.title)
      end

      it 'filters past schedules' do
        get '/api/v1/schedules', params: { past: 'true' }, headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:schedules].size).to eq(1)
        expect(json_response[:data][:schedules][0][:title]).to eq(past_schedule.title)
      end

      it 'filters by event_type' do
        scrim_event = create(:schedule, organization: organization, event_type: 'scrim')
        create(:schedule, organization: organization, event_type: 'meeting')

        get '/api/v1/schedules', params: { event_type: 'scrim' }, headers: auth_headers(user)

        titles = json_response[:data][:schedules].map { |s| s[:title] }
        expect(titles).to include(scrim_event.title)
      end

      it 'sorts ascending by start_time by default' do
        get '/api/v1/schedules', headers: auth_headers(user)

        times = json_response[:data][:schedules].map { |s| s[:start_time] }
        expect(times).to eq(times.sort)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/schedules'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'cross-organization isolation' do
      let(:other_org)  { create(:organization) }
      let(:other_user) { create(:user, :admin, organization: other_org) }

      it 'does not return schedules from another organization' do
        get '/api/v1/schedules', headers: auth_headers(other_user)

        expect(json_response[:data][:schedules]).to be_empty
      end
    end
  end

  describe 'POST /api/v1/schedules' do
    let(:valid_params) do
      {
        schedule: {
          title: 'Practice Session',
          event_type: 'scrim',
          start_time: 3.days.from_now.iso8601,
          end_time: (3.days.from_now + 2.hours).iso8601,
          status: 'scheduled'
        }
      }
    end

    context 'when authenticated as admin' do
      it 'creates the schedule and returns 201' do
        post '/api/v1/schedules', params: valid_params.to_json, headers: auth_headers(user)

        expect(response).to have_http_status(:created)
        expect(json_response[:data][:schedule][:title]).to eq('Practice Session')
      end

      it 'rejects end_time before start_time with 422' do
        params = valid_params.deep_merge(
          schedule: {
            end_time: (3.days.from_now - 1.hour).iso8601
          }
        )

        post '/api/v1/schedules', params: params.to_json, headers: auth_headers(user)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        post '/api/v1/schedules', params: valid_params.to_json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/schedules/:id' do
    let(:schedule) { create(:schedule, organization: organization) }

    context 'when authenticated' do
      it 'returns the schedule' do
        get "/api/v1/schedules/#{schedule.id}", headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:schedule][:id]).to eq(schedule.id)
      end
    end

    context 'when accessing another org schedule' do
      let(:other_org)      { create(:organization) }
      let(:other_user)     { create(:user, :admin, organization: other_org) }

      it 'returns 404' do
        get "/api/v1/schedules/#{schedule.id}", headers: auth_headers(other_user)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        get "/api/v1/schedules/#{schedule.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH /api/v1/schedules/:id' do
    let(:schedule) { create(:schedule, organization: organization) }

    context 'when authenticated as admin' do
      it 'updates the schedule title' do
        patch "/api/v1/schedules/#{schedule.id}",
              params: { schedule: { title: 'Updated Title' } }.to_json,
              headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:schedule][:title]).to eq('Updated Title')
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        patch "/api/v1/schedules/#{schedule.id}", params: {}.to_json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/schedules/:id' do
    let!(:schedule) { create(:schedule, organization: organization) }

    context 'when authenticated as admin' do
      it 'deletes the schedule and returns 200' do
        delete "/api/v1/schedules/#{schedule.id}", headers: auth_headers(user)

        expect(response).to have_http_status(:ok)
        expect { Schedule.find(schedule.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        delete "/api/v1/schedules/#{schedule.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
