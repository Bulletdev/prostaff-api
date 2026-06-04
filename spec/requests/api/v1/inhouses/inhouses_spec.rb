# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Inhouses API', type: :request do
  let(:organization) { create(:organization) }
  let(:coach)        { create(:user, :coach,  organization: organization) }
  let(:viewer)       { create(:user, :viewer, organization: organization) }

  # ── Helpers ────────────────────────────────────────────────────────────────

  def create_player_in_org(org, role: 'mid', tier: 'GOLD')
    create(:player, organization: org, role: role, solo_queue_tier: tier)
  end

  def add_player_to_inhouse(inhouse, player, team: 'none', role: nil)
    create(:inhouse_participation,
           inhouse: inhouse,
           player: player,
           team: team,
           role: role || player.role,
           tier_snapshot: player.solo_queue_tier)
  end

  # ── GET /api/v1/inhouse/inhouses ───────────────────────────────────────────

  describe 'GET /api/v1/inhouse/inhouses' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/inhouse/inhouses'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated' do
      let!(:done_inhouse)    { create(:inhouse, :done,  organization: organization) }
      let!(:active_inhouse)  { create(:inhouse, :waiting, organization: organization) }

      it 'returns 200' do
        get '/api/v1/inhouse/inhouses', headers: auth_headers(coach)
        expect(response).to have_http_status(:ok)
      end

      it 'defaults to returning only done (history) sessions' do
        get '/api/v1/inhouse/inhouses', headers: auth_headers(coach)
        ids = json_response[:data][:inhouses].map { |i| i[:id] }
        expect(ids).to include(done_inhouse.id)
        expect(ids).not_to include(active_inhouse.id)
      end

      it 'returns active sessions when ?all=true is passed' do
        get '/api/v1/inhouse/inhouses', params: { all: true }, headers: auth_headers(coach)
        ids = json_response[:data][:inhouses].map { |i| i[:id] }
        expect(ids).to include(done_inhouse.id)
        expect(ids).to include(active_inhouse.id)
      end

      it 'returns pagination metadata' do
        get '/api/v1/inhouse/inhouses', headers: auth_headers(coach)
        expect(json_response[:data][:meta]).to include(:current_page, :total_pages, :total_count)
      end

      context 'cross-organization isolation' do
        let(:other_org)   { create(:organization) }
        let(:other_user)  { create(:user, :coach, organization: other_org) }
        let!(:other_done) { create(:inhouse, :done, organization: other_org) }

        it 'does not expose sessions from another organization' do
          get '/api/v1/inhouse/inhouses', headers: auth_headers(other_user)
          ids = json_response[:data][:inhouses].map { |i| i[:id] }
          expect(ids).not_to include(done_inhouse.id)
          expect(ids).to include(other_done.id)
        end
      end
    end
  end

  # ── GET /api/v1/inhouse/inhouses/active ────────────────────────────────────

  describe 'GET /api/v1/inhouse/inhouses/active' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/inhouse/inhouses/active'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when there is no active session' do
      it 'returns inhouse: nil' do
        get '/api/v1/inhouse/inhouses/active', headers: auth_headers(coach)
        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:inhouse]).to be_nil
      end
    end

    context 'when an active session exists' do
      let!(:active_inhouse) { create(:inhouse, :waiting, organization: organization) }

      it 'returns the active session' do
        get '/api/v1/inhouse/inhouses/active', headers: auth_headers(coach)
        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:inhouse][:id]).to eq(active_inhouse.id)
        expect(json_response[:data][:inhouse][:status]).to eq('waiting')
      end
    end
  end

  # ── POST /api/v1/inhouse/inhouses ──────────────────────────────────────────

  describe 'POST /api/v1/inhouse/inhouses' do
    context 'when unauthenticated' do
      it 'returns 401' do
        post '/api/v1/inhouse/inhouses'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as coach' do
      it 'creates a new inhouse session with status waiting' do
        expect do
          post '/api/v1/inhouse/inhouses', headers: auth_headers(coach)
        end.to change { organization.inhouses.count }.by(1)

        expect(response).to have_http_status(:created)
        expect(json_response[:data][:inhouse][:status]).to eq('waiting')
      end

      it 'returns 422 when an active session already exists' do
        create(:inhouse, :waiting, organization: organization)

        post '/api/v1/inhouse/inhouses', headers: auth_headers(coach)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('ACTIVE_INHOUSE_EXISTS')
      end
    end

    context 'when authenticated as viewer' do
      it 'returns 403' do
        post '/api/v1/inhouse/inhouses', headers: auth_headers(viewer)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ── POST /api/v1/inhouse/inhouses/:id/join ─────────────────────────────────

  describe 'POST /api/v1/inhouse/inhouses/:id/join' do
    let!(:inhouse) { create(:inhouse, :waiting, organization: organization) }
    let!(:player)  { create_player_in_org(organization, role: 'mid') }

    context 'when unauthenticated' do
      it 'returns 401' do
        post "/api/v1/inhouse/inhouses/#{inhouse.id}/join"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as coach' do
      it 'adds a player to the inhouse lobby' do
        post "/api/v1/inhouse/inhouses/#{inhouse.id}/join",
             params: { player_id: player.id }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:ok)
        expect(inhouse.inhouse_participations.where(player: player).count).to eq(1)
      end

      it 'returns 422 if the player is already in the session' do
        add_player_to_inhouse(inhouse, player)

        post "/api/v1/inhouse/inhouses/#{inhouse.id}/join",
             params: { player_id: player.id }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('ALREADY_JOINED')
      end

      it 'returns 404 if player belongs to another organization' do
        other_player = create_player_in_org(create(:organization))

        post "/api/v1/inhouse/inhouses/#{inhouse.id}/join",
             params: { player_id: other_player.id }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:not_found)
        expect(json_response[:error][:code]).to eq('PLAYER_NOT_FOUND')
      end

      it 'returns 422 if the session is not in waiting state' do
        inhouse.update!(status: 'in_progress')

        post "/api/v1/inhouse/inhouses/#{inhouse.id}/join",
             params: { player_id: player.id }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('INVALID_STATE')
      end
    end

    context 'when authenticated as viewer' do
      it 'returns 403' do
        post "/api/v1/inhouse/inhouses/#{inhouse.id}/join",
             params: { player_id: player.id }.to_json,
             headers: auth_headers(viewer)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ── POST /api/v1/inhouse/inhouses/:id/balance_teams ────────────────────────

  describe 'POST /api/v1/inhouse/inhouses/:id/balance_teams' do
    let!(:inhouse) { create(:inhouse, :waiting, organization: organization) }
    let!(:players) do
      %w[top jungle mid adc support].map do |role|
        [
          create_player_in_org(organization, role: role, tier: 'DIAMOND'),
          create_player_in_org(organization, role: role, tier: 'GOLD')
        ]
      end.flatten
    end

    before do
      players.each { |p| add_player_to_inhouse(inhouse, p) }
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        post "/api/v1/inhouse/inhouses/#{inhouse.id}/balance_teams"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as coach' do
      it 'assigns all players to blue or red team' do
        post "/api/v1/inhouse/inhouses/#{inhouse.id}/balance_teams",
             headers: auth_headers(coach)

        expect(response).to have_http_status(:ok)
        teams = inhouse.inhouse_participations.reload.map(&:team).uniq.sort
        expect(teams).to include('blue', 'red')
        expect(teams).not_to include('none')
      end

      it 'transitions status to in_progress' do
        post "/api/v1/inhouse/inhouses/#{inhouse.id}/balance_teams",
             headers: auth_headers(coach)

        expect(inhouse.reload.status).to eq('in_progress')
      end

      it 'returns 422 if fewer than 2 players are in the session' do
        empty_inhouse = create(:inhouse, :waiting, organization: organization)

        post "/api/v1/inhouse/inhouses/#{empty_inhouse.id}/balance_teams",
             headers: auth_headers(coach)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('NOT_ENOUGH_PLAYERS')
      end

      it 'returns 422 if the session is already done' do
        inhouse.update_columns(status: 'done')

        post "/api/v1/inhouse/inhouses/#{inhouse.id}/balance_teams",
             headers: auth_headers(coach)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('INVALID_STATE')
      end
    end

    context 'when authenticated as viewer' do
      it 'returns 403' do
        post "/api/v1/inhouse/inhouses/#{inhouse.id}/balance_teams",
             headers: auth_headers(viewer)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ── POST /api/v1/inhouse/inhouses/:id/start_draft ──────────────────────────

  describe 'POST /api/v1/inhouse/inhouses/:id/start_draft' do
    let!(:inhouse)      { create(:inhouse, :waiting, organization: organization) }
    let!(:blue_player)  { create_player_in_org(organization, role: 'mid') }
    let!(:red_player)   { create_player_in_org(organization, role: 'top') }

    before do
      add_player_to_inhouse(inhouse, blue_player)
      add_player_to_inhouse(inhouse, red_player)
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        post "/api/v1/inhouse/inhouses/#{inhouse.id}/start_draft"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as coach' do
      it 'transitions the session to draft and assigns captains' do
        post "/api/v1/inhouse/inhouses/#{inhouse.id}/start_draft",
             params: { blue_captain_id: blue_player.id, red_captain_id: red_player.id }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:ok)
        inhouse.reload
        expect(inhouse.status).to eq('draft')
        expect(inhouse.blue_captain_id).to eq(blue_player.id)
        expect(inhouse.red_captain_id).to eq(red_player.id)
        expect(inhouse.formation_mode).to eq('captain_draft')
      end

      it 'returns 422 if session is not in waiting state' do
        inhouse.update_columns(status: 'in_progress')

        post "/api/v1/inhouse/inhouses/#{inhouse.id}/start_draft",
             params: { blue_captain_id: blue_player.id, red_captain_id: red_player.id }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('INVALID_STATE')
      end

      it 'returns 422 if blue and red captain are the same player' do
        post "/api/v1/inhouse/inhouses/#{inhouse.id}/start_draft",
             params: { blue_captain_id: blue_player.id, red_captain_id: blue_player.id }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('DUPLICATE_CAPTAIN')
      end

      it 'returns 422 if captain IDs are missing' do
        post "/api/v1/inhouse/inhouses/#{inhouse.id}/start_draft",
             params: {}.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('MISSING_PARAMS')
      end

      it 'returns 422 if captain is not in the session' do
        outside_player = create_player_in_org(organization)

        post "/api/v1/inhouse/inhouses/#{inhouse.id}/start_draft",
             params: { blue_captain_id: blue_player.id, red_captain_id: outside_player.id }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('CAPTAIN_NOT_IN_SESSION')
      end
    end

    context 'when authenticated as viewer' do
      it 'returns 403' do
        post "/api/v1/inhouse/inhouses/#{inhouse.id}/start_draft",
             params: { blue_captain_id: blue_player.id, red_captain_id: red_player.id }.to_json,
             headers: auth_headers(viewer)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ── POST /api/v1/inhouse/inhouses/:id/captain_pick ─────────────────────────

  describe 'POST /api/v1/inhouse/inhouses/:id/captain_pick' do
    let!(:inhouse) { create(:inhouse, organization: organization) }
    let!(:blue_captain_player) { create_player_in_org(organization, role: 'mid') }
    let!(:red_captain_player)  { create_player_in_org(organization, role: 'top') }
    let!(:pickable_player)     { create_player_in_org(organization, role: 'adc') }

    before do
      # Set up draft state directly to avoid status transition concerns
      inhouse.update_columns(
        status: 'draft',
        formation_mode: 'captain_draft',
        blue_captain_id: blue_captain_player.id,
        red_captain_id: red_captain_player.id,
        draft_pick_number: 0
      )
      create(:inhouse_participation, :captain, inhouse: inhouse, player: blue_captain_player,
             team: 'blue', role: 'mid')
      create(:inhouse_participation, :captain, inhouse: inhouse, player: red_captain_player,
             team: 'red', role: 'top')
      create(:inhouse_participation, inhouse: inhouse, player: pickable_player,
             team: 'none', role: 'adc')
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        post "/api/v1/inhouse/inhouses/#{inhouse.id}/captain_pick"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as coach' do
      it 'assigns the picked player to the current pick team' do
        # PICK_ORDER[0] is 'blue', so blue picks first
        post "/api/v1/inhouse/inhouses/#{inhouse.id}/captain_pick",
             params: { player_id: pickable_player.id }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:ok)
        expect(InhouseParticipation.find_by(inhouse: inhouse, player: pickable_player).team).to eq('blue')
        expect(inhouse.reload.draft_pick_number).to eq(1)
      end

      it 'returns 422 when session is not in draft phase' do
        inhouse.update_columns(status: 'in_progress')

        post "/api/v1/inhouse/inhouses/#{inhouse.id}/captain_pick",
             params: { player_id: pickable_player.id }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('INVALID_STATE')
      end

      it 'returns 422 when trying to pick a captain' do
        post "/api/v1/inhouse/inhouses/#{inhouse.id}/captain_pick",
             params: { player_id: blue_captain_player.id }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('PLAYER_IS_CAPTAIN')
      end

      it 'returns 422 when player is already picked' do
        InhouseParticipation.find_by(inhouse: inhouse, player: pickable_player).update!(team: 'blue')

        post "/api/v1/inhouse/inhouses/#{inhouse.id}/captain_pick",
             params: { player_id: pickable_player.id }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('ALREADY_PICKED')
      end

      it 'returns 404 if player is not in the session' do
        outside_player = create_player_in_org(organization)

        post "/api/v1/inhouse/inhouses/#{inhouse.id}/captain_pick",
             params: { player_id: outside_player.id }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:not_found)
        expect(json_response[:error][:code]).to eq('PLAYER_NOT_IN_SESSION')
      end
    end

    context 'when authenticated as viewer' do
      it 'returns 403' do
        post "/api/v1/inhouse/inhouses/#{inhouse.id}/captain_pick",
             params: { player_id: pickable_player.id }.to_json,
             headers: auth_headers(viewer)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ── POST /api/v1/inhouse/inhouses/:id/record_game ──────────────────────────

  describe 'POST /api/v1/inhouse/inhouses/:id/record_game' do
    # Inhouse with no participations — avoids TrueSkillService.upsert_all
    # which triggers a constraint issue under DatabaseCleaner :transaction.
    let!(:inhouse)     { create(:inhouse, :in_progress, organization: organization) }
    let!(:blue_player) { create_player_in_org(organization, role: 'mid') }
    let!(:red_player)  { create_player_in_org(organization, role: 'top') }

    before do
      allow(TrueSkillService).to receive(:update_ratings)
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        post "/api/v1/inhouse/inhouses/#{inhouse.id}/record_game"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as coach' do
      it 'records a blue win and increments counters' do
        post "/api/v1/inhouse/inhouses/#{inhouse.id}/record_game",
             params: { winner: 'blue' }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:ok)
        inhouse.reload
        expect(inhouse.games_played).to eq(1)
        expect(inhouse.blue_wins).to eq(1)
        expect(inhouse.red_wins).to eq(0)
      end

      it 'records a red win and increments counters' do
        post "/api/v1/inhouse/inhouses/#{inhouse.id}/record_game",
             params: { winner: 'red' }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:ok)
        inhouse.reload
        expect(inhouse.games_played).to eq(1)
        expect(inhouse.blue_wins).to eq(0)
        expect(inhouse.red_wins).to eq(1)
      end

      it 'calls TrueSkillService.update_ratings with the inhouse and winner' do
        post "/api/v1/inhouse/inhouses/#{inhouse.id}/record_game",
             params: { winner: 'blue' }.to_json,
             headers: auth_headers(coach)

        expect(TrueSkillService).to have_received(:update_ratings).with(
          instance_of(Inhouse), 'blue'
        )
      end

      context 'with participations' do
        before do
          add_player_to_inhouse(inhouse, blue_player, team: 'blue')
          add_player_to_inhouse(inhouse, red_player,  team: 'red')
        end

        it 'updates wins for the winning team participation' do
          post "/api/v1/inhouse/inhouses/#{inhouse.id}/record_game",
               params: { winner: 'blue' }.to_json,
               headers: auth_headers(coach)

          blue_part = InhouseParticipation.find_by(inhouse: inhouse, player: blue_player)
          red_part  = InhouseParticipation.find_by(inhouse: inhouse, player: red_player)
          expect(blue_part.reload.wins).to eq(1)
          expect(red_part.reload.losses).to eq(1)
        end

        it 'updates PlayerInhouseRating after recording a game' do
          allow(TrueSkillService).to receive(:update_ratings).and_call_original
          expect do
            post "/api/v1/inhouse/inhouses/#{inhouse.id}/record_game",
                 params: { winner: 'blue' }.to_json,
                 headers: auth_headers(coach)
          end.to change { PlayerInhouseRating.count }.by_at_least(1)
        end

        it 'ensures PlayerInhouseRating MMR is never negative' do
          allow(TrueSkillService).to receive(:update_ratings).and_call_original
          post "/api/v1/inhouse/inhouses/#{inhouse.id}/record_game",
               params: { winner: 'blue' }.to_json,
               headers: auth_headers(coach)

          PlayerInhouseRating.where(
            player_id: [blue_player.id, red_player.id]
          ).each do |rating|
            expect(rating.mmr).to be >= 0
          end
        end
      end

      it 'returns 422 if the session is not in_progress' do
        inhouse.update_columns(status: 'waiting')

        post "/api/v1/inhouse/inhouses/#{inhouse.id}/record_game",
             params: { winner: 'blue' }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('INVALID_STATE')
      end

      it 'returns 422 for an invalid winner value' do
        post "/api/v1/inhouse/inhouses/#{inhouse.id}/record_game",
             params: { winner: 'purple' }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('INVALID_WINNER')
      end
    end

    context 'when authenticated as viewer' do
      it 'returns 403' do
        post "/api/v1/inhouse/inhouses/#{inhouse.id}/record_game",
             params: { winner: 'blue' }.to_json,
             headers: auth_headers(viewer)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ── PATCH /api/v1/inhouse/inhouses/:id/close ───────────────────────────────

  describe 'PATCH /api/v1/inhouse/inhouses/:id/close' do
    let!(:inhouse) { create(:inhouse, organization: organization) }

    before { inhouse.update_columns(status: 'in_progress') }

    context 'when unauthenticated' do
      it 'returns 401' do
        patch "/api/v1/inhouse/inhouses/#{inhouse.id}/close"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as coach' do
      it 'transitions the session to done' do
        patch "/api/v1/inhouse/inhouses/#{inhouse.id}/close",
              headers: auth_headers(coach)

        expect(response).to have_http_status(:ok)
        expect(inhouse.reload.status).to eq('done')
      end

      it 'returns 422 if the session is already closed' do
        inhouse.update_columns(status: 'done')

        patch "/api/v1/inhouse/inhouses/#{inhouse.id}/close",
              headers: auth_headers(coach)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('ALREADY_CLOSED')
      end
    end

    context 'when authenticated as viewer' do
      it 'returns 403' do
        patch "/api/v1/inhouse/inhouses/#{inhouse.id}/close",
              headers: auth_headers(viewer)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ── GET /api/v1/inhouse/ladder ─────────────────────────────────────────────

  describe 'GET /api/v1/inhouse/ladder' do
    let!(:player) { create_player_in_org(organization, role: 'mid') }
    let!(:rating) { create(:player_inhouse_rating, :experienced, player: player, organization: organization, role: 'mid') }

    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/inhouse/ladder'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated' do
      it 'returns the ladder sorted by MMR descending' do
        get '/api/v1/inhouse/ladder', headers: auth_headers(coach)

        expect(response).to have_http_status(:ok)
        entries = json_response[:data][:entries]
        expect(entries).not_to be_empty
        expect(entries.first[:rank]).to eq(1)
        mmrs = entries.map { |e| e[:mmr] }
        expect(mmrs).to eq(mmrs.sort.reverse)
      end

      it 'returns entries with expected fields' do
        get '/api/v1/inhouse/ladder', headers: auth_headers(coach)

        entry = json_response[:data][:entries].find { |e| e[:player_id] == player.id }
        expect(entry).to include(:player_id, :player_name, :role, :mu, :sigma, :mmr, :games_played, :wins, :losses,
                                 :win_rate)
      end

      it 'MMR is never negative' do
        get '/api/v1/inhouse/ladder', headers: auth_headers(coach)

        json_response[:data][:entries].each do |entry|
          expect(entry[:mmr]).to be >= 0
        end
      end

      it 'filters by role when ?role param is provided' do
        other_player = create_player_in_org(organization, role: 'top')
        create(:player_inhouse_rating, player: other_player, organization: organization, role: 'top')

        get '/api/v1/inhouse/ladder', params: { role: 'mid' }, headers: auth_headers(coach)

        roles = json_response[:data][:entries].map { |e| e[:role] }.uniq
        expect(roles).to eq(['mid'])
      end

      context 'cross-organization isolation' do
        let(:other_org)    { create(:organization) }
        let(:other_user)   { create(:user, :coach, organization: other_org) }
        let(:other_player) { create_player_in_org(other_org, role: 'mid') }

        before do
          create(:player_inhouse_rating, player: other_player, organization: other_org, role: 'mid')
        end

        it 'does not expose ratings from another organization' do
          get '/api/v1/inhouse/ladder', headers: auth_headers(other_user)

          ids = json_response[:data][:entries].map { |e| e[:player_id] }
          expect(ids).not_to include(player.id)
          expect(ids).to include(other_player.id)
        end
      end
    end
  end

  # ── GET /api/v1/inhouse/sessions ───────────────────────────────────────────

  describe 'GET /api/v1/inhouse/sessions' do
    let!(:done_inhouse) { create(:inhouse, :done, organization: organization) }

    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/inhouse/sessions'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated' do
      it 'returns only done sessions with summary' do
        get '/api/v1/inhouse/sessions', headers: auth_headers(coach)

        expect(response).to have_http_status(:ok)
        sessions = json_response[:data][:sessions]
        expect(sessions).not_to be_empty
        expect(sessions.first).to include(:id, :games_played, :blue_wins, :red_wins, :formation_mode)
      end

      it 'returns pagination meta' do
        get '/api/v1/inhouse/sessions', headers: auth_headers(coach)
        expect(json_response[:data][:meta]).to include(:current_page, :total_pages, :total_count)
      end
    end
  end
end
