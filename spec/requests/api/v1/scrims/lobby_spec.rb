# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Scrims Lobby API', type: :request do
  # LobbyController is fully public — no authentication required.
  # The lobby queries for visibility: 'public' scrims — this value is not in
  # Constants::Scrim::VISIBILITY_LEVELS so we set it via update_column to bypass validation.

  def create_public_scrim(organization:, scheduled_at: 2.days.from_now, **attrs)
    scrim = create(:scrim, organization: organization, scheduled_at: scheduled_at, **attrs)
    scrim.update_column(:visibility, 'public')
    scrim
  end

  describe 'GET /api/v1/scrims/lobby' do
    context 'when there are no public scrims' do
      it 'returns 200 with empty list' do
        get '/api/v1/scrims/lobby'

        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:scrims]).to eq([])
      end

      it 'includes pagination metadata' do
        get '/api/v1/scrims/lobby'

        pagination = json_response[:data][:pagination]
        expect(pagination).to include(
          :current_page,
          :per_page,
          :total_pages,
          :total_count
        )
      end
    end

    context 'when a public organization has public upcoming scrims' do
      let!(:public_org) do
        create(:organization, is_public: true, tier: 'tier_2_semi_pro', region: 'BR')
      end
      let!(:public_scrim) { create_public_scrim(organization: public_org) }

      it 'returns 200 and includes the public scrim' do
        get '/api/v1/scrims/lobby'

        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:scrims]).not_to be_empty
      end

      it 'serializes required fields for each entry' do
        get '/api/v1/scrims/lobby'

        entry = json_response[:data][:scrims].first
        expect(entry).to include(:id, :scheduled_at, :status, :source, :organization)
      end

      it 'serializes organization without sensitive fields' do
        get '/api/v1/scrims/lobby'

        org_data = json_response[:data][:scrims].first[:organization]
        expect(org_data.keys).not_to include(:subscription_plan, :is_public)
        expect(org_data).to include(:id, :name, :region)
      end
    end

    context 'when a private organization has upcoming scrims' do
      let!(:private_org)   { create(:organization, is_public: false, tier: 'tier_2_semi_pro') }
      let!(:private_scrim) { create_public_scrim(organization: private_org) }

      it 'does not include scrims from private organizations' do
        get '/api/v1/scrims/lobby'

        returned_ids = json_response[:data][:scrims].map { |s| s[:id] }
        expect(returned_ids).not_to include(private_scrim.id)
      end
    end

    context 'when a public org has a non-public (internal) scrim' do
      let!(:public_org)     { create(:organization, is_public: true, tier: 'tier_2_semi_pro') }
      # Use a valid visibility from Constants::Scrim::VISIBILITY_LEVELS
      let!(:internal_scrim) { create(:scrim, organization: public_org, scheduled_at: 2.days.from_now) }

      it 'does not include internal scrims' do
        get '/api/v1/scrims/lobby'

        returned_ids = json_response[:data][:scrims].map { |s| s[:id] }
        expect(returned_ids).not_to include(internal_scrim.id)
      end
    end

    context 'when filtering by game' do
      let!(:public_org) { create(:organization, is_public: true, tier: 'tier_2_semi_pro', region: 'BR') }
      let!(:lol_scrim)  { create_public_scrim(organization: public_org, game: 'league_of_legends') }

      it 'returns 200 for a valid game filter' do
        get '/api/v1/scrims/lobby', params: { game: 'league_of_legends' }

        expect(response).to have_http_status(:ok)
      end

      it 'ignores invalid game filter values and returns 200 without error' do
        # When game param is invalid, the controller treats it as nil (no filter applied).
        # This is the expected safe-list behavior — no 422, no crash.
        get '/api/v1/scrims/lobby', params: { game: 'invalid_game_xyz' }

        expect(response).to have_http_status(:ok)
        expect(json_response[:data]).to include(:scrims, :pagination)
        _ = lol_scrim
      end
    end

    context 'when filtering by region' do
      it 'accepts valid region codes' do
        %w[BR NA EUW KR].each do |region|
          get '/api/v1/scrims/lobby', params: { region: region }
          expect(response).to have_http_status(:ok)
        end
      end

      it 'ignores invalid region values and returns 200' do
        get '/api/v1/scrims/lobby', params: { region: 'INVALID_REGION' }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'pagination' do
      it 'clamps per_page to a maximum of 50' do
        get '/api/v1/scrims/lobby', params: { per_page: 1000 }

        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:pagination][:per_page]).to be <= 50
      end

      it 'defaults page to 1 when not provided' do
        get '/api/v1/scrims/lobby'

        expect(json_response[:data][:pagination][:current_page]).to eq(1)
      end
    end

    context 'when availability windows exist for public organizations' do
      let!(:public_org) do
        create(:organization, is_public: true, tier: 'tier_2_semi_pro', region: 'BR')
      end
      let!(:active_window) do
        create(:availability_window,
               organization: public_org,
               active: true,
               expires_at: nil,
               day_of_week: (Time.current.wday + 1) % 7)
      end

      it 'returns 200 without raising errors' do
        get '/api/v1/scrims/lobby'

        expect(response).to have_http_status(:ok)
      end

      it 'window entries use namespaced IDs prefixed with "window-"' do
        get '/api/v1/scrims/lobby'

        window_entries = json_response[:data][:scrims].select do |e|
          e[:id].to_s.start_with?('window-')
        end

        window_entries.each do |entry|
          expect(entry[:source]).to eq('availability_window')
        end
      end
    end

    context 'roster serialization' do
      let!(:public_org) do
        create(:organization, is_public: true, tier: 'tier_2_semi_pro', region: 'BR')
      end
      let!(:active_player) do
        create(:player, organization: public_org, status: 'active', role: 'mid', deleted_at: nil)
      end
      let!(:public_scrim) { create_public_scrim(organization: public_org) }

      it 'includes roster with valid LoL roles only' do
        get '/api/v1/scrims/lobby'

        roster = json_response[:data][:scrims].first[:organization][:roster]
        valid_roles = %w[top jungle mid adc support]
        roster.each do |member|
          next unless member[:role].present?

          expect(valid_roles).to include(member[:role])
        end
      end
    end
  end
end
