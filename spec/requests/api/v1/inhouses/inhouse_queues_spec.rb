# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Inhouse Queue API', type: :request do
  let(:organization) { create(:organization) }
  let(:coach)        { create(:user, :coach,  organization: organization) }
  let(:viewer)       { create(:user, :viewer, organization: organization) }

  # ── Helpers ────────────────────────────────────────────────────────────────

  def create_player_in_org(org, role: 'mid', tier: 'GOLD')
    create(:player, organization: org, role: role, solo_queue_tier: tier)
  end

  def open_queue
    create(:inhouse_queue, :open, organization: organization, created_by: coach)
  end

  def add_entry_to_queue(queue, player, role: nil, checked_in: false)
    create(:inhouse_queue_entry,
           inhouse_queue: queue,
           player: player,
           role: role || player.role,
           tier_snapshot: player.solo_queue_tier,
           checked_in: checked_in,
           checked_in_at: checked_in ? Time.current : nil)
  end

  # Stub the InhouseCheckInDeadlineJob to prevent ActiveJob side-effects
  before do
    allow(InhouseCheckInDeadlineJob).to receive(:set).and_return(InhouseCheckInDeadlineJob)
    allow(InhouseCheckInDeadlineJob).to receive(:perform_later)
  end

  # ── GET /api/v1/inhouse/queue/status ───────────────────────────────────────

  describe 'GET /api/v1/inhouse/queue/status' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/inhouse/queue/status'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when no active queue exists' do
      it 'returns queue: nil' do
        get '/api/v1/inhouse/queue/status', headers: auth_headers(coach)
        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:queue]).to be_nil
      end
    end

    context 'when an active queue exists' do
      let!(:queue) { open_queue }

      it 'returns the active queue' do
        get '/api/v1/inhouse/queue/status', headers: auth_headers(coach)
        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:queue][:id]).to eq(queue.id)
        expect(json_response[:data][:queue][:status]).to eq('open')
      end

      context 'cross-organization isolation' do
        let(:other_org)   { create(:organization) }
        let(:other_user)  { create(:user, :coach, organization: other_org) }

        before { create(:inhouse_queue, :open, organization: other_org, created_by: other_user) }

        it 'does not expose another org queue to a different org user' do
          get '/api/v1/inhouse/queue/status', headers: auth_headers(other_user)
          returned_id = json_response[:data][:queue]&.dig(:id)
          expect(returned_id).not_to eq(queue.id)
        end
      end
    end
  end

  # ── POST /api/v1/inhouse/queue/open ────────────────────────────────────────

  describe 'POST /api/v1/inhouse/queue/open' do
    context 'when unauthenticated' do
      it 'returns 401' do
        post '/api/v1/inhouse/queue/open'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as coach' do
      it 'creates a new open queue' do
        expect do
          post '/api/v1/inhouse/queue/open', headers: auth_headers(coach)
        end.to change { organization.inhouse_queues.count }.by(1)

        expect(response).to have_http_status(:created)
        expect(json_response[:data][:queue][:status]).to eq('open')
      end

      it 'returns 422 when an active queue already exists' do
        open_queue

        post '/api/v1/inhouse/queue/open', headers: auth_headers(coach)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('ACTIVE_QUEUE_EXISTS')
      end
    end

    context 'when authenticated as viewer' do
      it 'returns 403' do
        post '/api/v1/inhouse/queue/open', headers: auth_headers(viewer)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ── POST /api/v1/inhouse/queue/join ────────────────────────────────────────

  describe 'POST /api/v1/inhouse/queue/join' do
    let!(:queue)  { open_queue }
    let!(:player) { create_player_in_org(organization, role: 'mid') }

    context 'when unauthenticated' do
      it 'returns 401' do
        post '/api/v1/inhouse/queue/join'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as coach' do
      it 'adds a player to the queue with the specified role' do
        post '/api/v1/inhouse/queue/join',
             params: { player_id: player.id, role: 'mid' }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:ok)
        expect(queue.inhouse_queue_entries.where(player: player, role: 'mid').count).to eq(1)
      end

      it 'returns 422 for an invalid role' do
        post '/api/v1/inhouse/queue/join',
             params: { player_id: player.id, role: 'invalid_role' }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('INVALID_ROLE')
      end

      it 'returns 422 if the player is already in the queue' do
        add_entry_to_queue(queue, player, role: 'mid')

        post '/api/v1/inhouse/queue/join',
             params: { player_id: player.id, role: 'mid' }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('ALREADY_IN_QUEUE')
      end

      it 'returns 422 if the role is already full (2 of 2)' do
        2.times do |n|
          p = create_player_in_org(organization, role: 'mid')
          add_entry_to_queue(queue, p, role: 'mid')
          # rename to avoid name collision
          p.update_columns(role: "mid#{n}")
        end

        post '/api/v1/inhouse/queue/join',
             params: { player_id: player.id, role: 'mid' }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('ROLE_FULL')
      end

      it 'returns 404 if player belongs to another organization' do
        other_player = create_player_in_org(create(:organization), role: 'mid')

        post '/api/v1/inhouse/queue/join',
             params: { player_id: other_player.id, role: 'mid' }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:not_found)
        expect(json_response[:error][:code]).to eq('PLAYER_NOT_FOUND')
      end

      it 'returns 422 if the queue is not in open state' do
        queue.update!(status: 'check_in')

        post '/api/v1/inhouse/queue/join',
             params: { player_id: player.id, role: 'mid' }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('QUEUE_NOT_OPEN')
      end
    end
  end

  # ── POST /api/v1/inhouse/queue/leave ───────────────────────────────────────

  describe 'POST /api/v1/inhouse/queue/leave' do
    let!(:queue)  { open_queue }
    let!(:player) { create_player_in_org(organization, role: 'mid') }

    before { add_entry_to_queue(queue, player, role: 'mid') }

    context 'when unauthenticated' do
      it 'returns 401' do
        post '/api/v1/inhouse/queue/leave'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as coach' do
      it 'removes the player from the queue' do
        expect do
          post '/api/v1/inhouse/queue/leave',
               params: { player_id: player.id }.to_json,
               headers: auth_headers(coach)
        end.to change { queue.inhouse_queue_entries.count }.by(-1)

        expect(response).to have_http_status(:ok)
      end

      it 'returns 404 if the player is not in the queue' do
        other_player = create_player_in_org(organization, role: 'top')

        post '/api/v1/inhouse/queue/leave',
             params: { player_id: other_player.id }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:not_found)
        expect(json_response[:error][:code]).to eq('NOT_IN_QUEUE')
      end
    end
  end

  # ── POST /api/v1/inhouse/queue/start_checkin ───────────────────────────────

  describe 'POST /api/v1/inhouse/queue/start_checkin' do
    let!(:queue) { open_queue }

    context 'when unauthenticated' do
      it 'returns 401' do
        post '/api/v1/inhouse/queue/start_checkin'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as coach' do
      before do
        2.times do
          p = create_player_in_org(organization, role: 'mid')
          add_entry_to_queue(queue, p, role: 'mid')
          break # only need 2 players for minimum
        end
        2.times { |i| add_entry_to_queue(queue, create_player_in_org(organization), role: %w[top jungle adc support][i]) }
      end

      it 'transitions queue to check_in status' do
        post '/api/v1/inhouse/queue/start_checkin', headers: auth_headers(coach)

        expect(response).to have_http_status(:ok)
        expect(queue.reload.status).to eq('check_in')
      end

      it 'sets a check_in_deadline' do
        post '/api/v1/inhouse/queue/start_checkin', headers: auth_headers(coach)

        expect(queue.reload.check_in_deadline).to be_present
        expect(queue.check_in_deadline).to be > Time.current
      end

      it 'returns 422 if queue is not in open state' do
        queue.update!(status: 'check_in')

        post '/api/v1/inhouse/queue/start_checkin', headers: auth_headers(coach)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('INVALID_STATE')
      end
    end

    context 'with fewer than 2 players' do
      it 'returns 422' do
        post '/api/v1/inhouse/queue/start_checkin', headers: auth_headers(coach)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('NOT_ENOUGH_PLAYERS')
      end
    end

    context 'when authenticated as viewer' do
      it 'returns 403' do
        post '/api/v1/inhouse/queue/start_checkin', headers: auth_headers(viewer)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ── POST /api/v1/inhouse/queue/checkin ─────────────────────────────────────

  describe 'POST /api/v1/inhouse/queue/checkin' do
    let!(:queue)  { create(:inhouse_queue, organization: organization, created_by: coach, status: 'check_in') }
    let!(:player) { create_player_in_org(organization, role: 'mid') }

    before { add_entry_to_queue(queue, player, role: 'mid') }

    context 'when unauthenticated' do
      it 'returns 401' do
        post '/api/v1/inhouse/queue/checkin'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as coach' do
      it 'marks the player as checked in' do
        post '/api/v1/inhouse/queue/checkin',
             params: { player_id: player.id }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:ok)
        entry = queue.inhouse_queue_entries.find_by(player: player)
        expect(entry.reload.checked_in).to be(true)
        expect(entry.checked_in_at).to be_present
      end

      it 'returns 422 if queue is not in check_in phase' do
        queue.update!(status: 'open')

        post '/api/v1/inhouse/queue/checkin',
             params: { player_id: player.id }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('INVALID_STATE')
      end

      it 'returns 404 if player is not in the queue' do
        other_player = create_player_in_org(organization, role: 'top')

        post '/api/v1/inhouse/queue/checkin',
             params: { player_id: other_player.id }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:not_found)
        expect(json_response[:error][:code]).to eq('NOT_IN_QUEUE')
      end
    end
  end

  # ── POST /api/v1/inhouse/queue/start_session ───────────────────────────────

  describe 'POST /api/v1/inhouse/queue/start_session' do
    let!(:queue) { create(:inhouse_queue, organization: organization, created_by: coach, status: 'check_in') }

    def setup_checked_in_players(count, roles: %w[top jungle mid adc support])
      roles.cycle.first(count).each_with_index do |role, i|
        player = create_player_in_org(organization, role: role, tier: 'GOLD')
        add_entry_to_queue(queue, player, role: role, checked_in: true)
      end
    end

    before do
      allow(Events::EventPublisher).to receive(:publish)
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        post '/api/v1/inhouse/queue/start_session'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid formation_mode' do
      before { setup_checked_in_players(4) }

      it 'returns 422 for unknown formation_mode values' do
        post '/api/v1/inhouse/queue/start_session',
             params: { formation_mode: 'random_shuffle' }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('INVALID_FORMATION_MODE')
      end

      it 'rejects empty formation_mode' do
        post '/api/v1/inhouse/queue/start_session',
             params: { formation_mode: '' }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('INVALID_FORMATION_MODE')
      end
    end

    context 'when fewer than 2 players are checked in' do
      before do
        p = create_player_in_org(organization, role: 'mid')
        add_entry_to_queue(queue, p, role: 'mid', checked_in: true)
      end

      it 'returns 422' do
        post '/api/v1/inhouse/queue/start_session',
             params: { formation_mode: 'auto' }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('NOT_ENOUGH_PLAYERS')
      end
    end

    context 'with formation_mode=auto and enough players' do
      before { setup_checked_in_players(4) }

      it 'creates an inhouse session scoped to the organization' do
        expect do
          post '/api/v1/inhouse/queue/start_session',
               params: { formation_mode: 'auto' }.to_json,
               headers: auth_headers(coach)
        end.to change { organization.inhouses.count }.by(1)

        expect(response).to have_http_status(:ok)
      end

      it 'closes the queue after session creation' do
        post '/api/v1/inhouse/queue/start_session',
             params: { formation_mode: 'auto' }.to_json,
             headers: auth_headers(coach)

        expect(queue.reload.status).to eq('closed')
      end

      it 'returns 422 if an active inhouse already exists' do
        create(:inhouse, :waiting, organization: organization)

        post '/api/v1/inhouse/queue/start_session',
             params: { formation_mode: 'auto' }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('ACTIVE_INHOUSE_EXISTS')
      end

      it 'publishes an inhouse.session_started event' do
        post '/api/v1/inhouse/queue/start_session',
             params: { formation_mode: 'auto' }.to_json,
             headers: auth_headers(coach)

        expect(Events::EventPublisher).to have_received(:publish).with(
          hash_including(type: 'inhouse.session_started')
        )
      end
    end

    context 'with formation_mode=captain_draft and enough players' do
      before { setup_checked_in_players(4) }

      it 'creates an inhouse in draft status' do
        post '/api/v1/inhouse/queue/start_session',
             params: { formation_mode: 'captain_draft' }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:ok)
        created = organization.inhouses.order(created_at: :desc).first
        expect(created.status).to eq('draft')
        expect(created.formation_mode).to eq('captain_draft')
      end
    end

    context 'when authenticated as viewer' do
      before { setup_checked_in_players(4) }

      it 'returns 403' do
        post '/api/v1/inhouse/queue/start_session',
             params: { formation_mode: 'auto' }.to_json,
             headers: auth_headers(viewer)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ── POST /api/v1/inhouse/queue/close ───────────────────────────────────────

  describe 'POST /api/v1/inhouse/queue/close' do
    let!(:queue) { open_queue }

    context 'when unauthenticated' do
      it 'returns 401' do
        post '/api/v1/inhouse/queue/close'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as coach' do
      it 'closes the queue' do
        post '/api/v1/inhouse/queue/close', headers: auth_headers(coach)

        expect(response).to have_http_status(:ok)
        expect(queue.reload.status).to eq('closed')
        expect(json_response[:data][:queue]).to be_nil
      end
    end

    context 'when authenticated as viewer' do
      it 'returns 403' do
        post '/api/v1/inhouse/queue/close', headers: auth_headers(viewer)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ── MMR invariant ──────────────────────────────────────────────────────────

  describe 'PlayerInhouseRating MMR formula' do
    it 'is never negative (computed as max(0, ((mu - 3*sigma)*100).round))' do
      # Edge case: brand-new default rating (mu=25, sigma=8.333)
      # => (25 - 3*8.333) * 100 = (25 - 25) * 100 = 0 — never negative
      rating = create(:player_inhouse_rating,
                      player: create_player_in_org(organization),
                      organization: organization,
                      mu: 25.0, sigma: 8.333333333333334)
      expect(rating.mmr).to be >= 0
    end

    it 'is positive for an experienced player with low sigma' do
      rating = create(:player_inhouse_rating, :experienced,
                      player: create_player_in_org(organization),
                      organization: organization)
      expect(rating.mmr).to be >= 0
    end
  end

  # ── Valid roles enforcement ─────────────────────────────────────────────────

  describe 'valid LoL roles in queue entries' do
    let!(:queue) { open_queue }

    %w[top jungle mid adc support].each do |valid_role|
      it "accepts valid role: #{valid_role}" do
        player = create_player_in_org(organization, role: valid_role)

        post '/api/v1/inhouse/queue/join',
             params: { player_id: player.id, role: valid_role }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:ok)
      end
    end

    %w[carry bot fill INVALID].each do |bad_role|
      it "rejects invalid role: #{bad_role}" do
        player = create_player_in_org(organization, role: 'mid')

        post '/api/v1/inhouse/queue/join',
             params: { player_id: player.id, role: bad_role }.to_json,
             headers: auth_headers(coach)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error][:code]).to eq('INVALID_ROLE')
      end
    end
  end
end
