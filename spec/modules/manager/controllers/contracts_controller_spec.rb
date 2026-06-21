# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Manager::Contracts API', type: :request do
  let(:organization) { create(:organization, tier: 'tier_1_professional') }
  let(:player)       { create(:player, organization: organization) }

  # Helpers to build contracts without triggering overlap validations.
  # The no_overlapping_active_contract validation fires on :create when
  # status == 'active', so we create one active contract per unique player.
  def create_draft_contract(player: nil, **overrides)
    p = player || create(:player, organization: organization)
    create(:contract,
           organization: organization,
           player:       p,
           created_by:   create(:user, :admin, organization: organization),
           status:       'draft',
           **overrides)
  end

  def create_active_contract(player: nil, **overrides)
    p = player || create(:player, organization: organization)
    create(:contract, :active,
           organization: organization,
           player:       p,
           created_by:   create(:user, :admin, organization: organization),
           **overrides)
  end

  # ── GET /api/v1/manager/contracts ──────────────────────────────────────────

  describe 'GET /api/v1/manager/contracts' do
    let!(:contract) { create_draft_contract }

    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/manager/contracts'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as owner' do
      let(:user) { create(:user, :owner, organization: organization) }

      it 'returns 200 and includes the contract' do
        get '/api/v1/manager/contracts', headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:contracts]).to be_an(Array)
      end
    end

    context 'when authenticated as admin' do
      let(:user) { create(:user, :admin, organization: organization) }

      it 'returns 200' do
        get '/api/v1/manager/contracts', headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
      end

      it 'returns pagination metadata' do
        get '/api/v1/manager/contracts', headers: auth_headers(user)
        expect(json_response[:data][:pagination]).to include(
          :current_page, :per_page, :total_pages, :total_count
        )
      end
    end

    context 'when authenticated as manager' do
      let(:user) { create(:user, :manager, organization: organization) }

      it 'returns 200' do
        get '/api/v1/manager/contracts', headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when authenticated as coach' do
      let(:user) { create(:user, :coach, organization: organization) }

      it 'returns 403' do
        get '/api/v1/manager/contracts', headers: auth_headers(user)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when authenticated as viewer' do
      let(:user) { create(:user, :viewer, organization: organization) }

      it 'returns 403' do
        get '/api/v1/manager/contracts', headers: auth_headers(user)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'tenant isolation' do
      let(:user)      { create(:user, :admin, organization: organization) }
      let(:other_org) { create(:organization) }

      before do
        other_user   = create(:user, :admin, organization: other_org)
        other_player = create(:player, organization: other_org)
        create(:contract, organization: other_org, player: other_player,
               created_by: other_user, status: 'draft')
      end

      it 'returns only contracts belonging to the authenticated user organization' do
        get '/api/v1/manager/contracts', headers: auth_headers(user)
        returned_ids = json_response[:data][:contracts].map { |c| c[:id] }
        # The contract created by let!(:contract) above belongs to this org
        expect(returned_ids).to include(contract.id.to_s)
        # total_count should NOT include contracts from other_org
        total = json_response[:data][:pagination][:total_count]
        expect(total).to eq(1)
      end
    end
  end

  # ── POST /api/v1/manager/contracts ─────────────────────────────────────────

  describe 'POST /api/v1/manager/contracts' do
    context 'when unauthenticated' do
      it 'returns 401' do
        post '/api/v1/manager/contracts',
             params: { contract: {} }.to_json,
             headers: { 'Content-Type' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as admin' do
      let(:user) { create(:user, :admin, organization: organization) }

      context 'creating a player contract with valid player_id' do
        let(:params) do
          {
            contract: {
              player_id:     player.id,
              contract_type: 'player',
              start_date:    Date.current.to_s,
              end_date:      (Date.current + 1.year).to_s,
              base_salary:   5000,
              salary_period: 'monthly'
            }
          }
        end

        it 'returns 201' do
          post '/api/v1/manager/contracts',
               params: params.to_json,
               headers: auth_headers(user)
          expect(response).to have_http_status(:created)
        end

        it 'creates the contract in the database' do
          expect do
            post '/api/v1/manager/contracts',
                 params: params.to_json,
                 headers: auth_headers(user)
          end.to change { Contract.unscoped.count }.by(1)
        end

        it 'responds with the contract data' do
          post '/api/v1/manager/contracts',
               params: params.to_json,
               headers: auth_headers(user)
          expect(json_response[:data][:contract]).to be_present
        end
      end

      context 'creating a player-type contract without player_id' do
        let(:params) do
          {
            contract: {
              contract_type: 'player',
              start_date:    Date.current.to_s,
              end_date:      (Date.current + 1.year).to_s,
              base_salary:   5000,
              salary_period: 'monthly'
            }
          }
        end

        it 'returns 422 because assignee_present validation fails' do
          post '/api/v1/manager/contracts',
               params: params.to_json,
               headers: auth_headers(user)
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context 'creating a staff contract with valid staff_member_id' do
        let(:staff_member) do
          create(:staff_member,
                 organization: organization,
                 name:         'Analyst One',
                 role:         'analyst',
                 status:       'active')
        end

        let(:params) do
          {
            contract: {
              staff_member_id: staff_member.id,
              contract_type:   'staff',
              start_date:      Date.current.to_s,
              end_date:        (Date.current + 1.year).to_s,
              base_salary:     4000,
              salary_period:   'monthly'
            }
          }
        end

        it 'returns 201' do
          post '/api/v1/manager/contracts',
               params: params.to_json,
               headers: auth_headers(user)
          expect(response).to have_http_status(:created)
        end

        it 'creates a contract with staff_member_id set' do
          post '/api/v1/manager/contracts',
               params: params.to_json,
               headers: auth_headers(user)
          contract = Contract.unscoped.last
          expect(contract.staff_member_id).to eq(staff_member.id)
        end
      end
    end

    context 'when authenticated as coach' do
      let(:user) { create(:user, :coach, organization: organization) }

      it 'returns 403 before reaching contract validation' do
        post '/api/v1/manager/contracts',
             params: { contract: { player_id: player.id } }.to_json,
             headers: auth_headers(user)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ── GET /api/v1/manager/contracts/:id ──────────────────────────────────────

  describe 'GET /api/v1/manager/contracts/:id' do
    let!(:contract) { create_draft_contract(player: player) }

    context 'when unauthenticated' do
      it 'returns 401' do
        get "/api/v1/manager/contracts/#{contract.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as owner' do
      let(:user) { create(:user, :owner, organization: organization) }

      it 'returns 200 and the contract data' do
        get "/api/v1/manager/contracts/#{contract.id}", headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
        expect(json_response[:data][:contract]).to be_present
      end
    end

    context 'when authenticated as coach' do
      let(:user) { create(:user, :coach, organization: organization) }

      # coach is blocked at the before_action require_manager_access! level
      it 'returns 403' do
        get "/api/v1/manager/contracts/#{contract.id}", headers: auth_headers(user)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'tenant isolation — contract from another org returns 404' do
      let(:user)      { create(:user, :admin, organization: organization) }
      let(:other_org) { create(:organization) }
      let(:other_contract) do
        other_user   = create(:user, :admin, organization: other_org)
        other_player = create(:player, organization: other_org)
        create(:contract, organization: other_org, player: other_player,
               created_by: other_user, status: 'draft')
      end

      it 'returns 404 for a contract belonging to another organization' do
        get "/api/v1/manager/contracts/#{other_contract.id}", headers: auth_headers(user)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ── PATCH /api/v1/manager/contracts/:id/activate ───────────────────────────

  describe 'PATCH /api/v1/manager/contracts/:id/activate' do
    let(:user)     { create(:user, :admin, organization: organization) }
    let!(:contract) { create_draft_contract(player: player) }

    context 'when unauthenticated' do
      it 'returns 401' do
        patch "/api/v1/manager/contracts/#{contract.id}/activate"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it 'changes the contract status to active' do
      patch "/api/v1/manager/contracts/#{contract.id}/activate",
            headers: auth_headers(user)
      expect(response).to have_http_status(:ok)
      expect(contract.reload.status).to eq('active')
    end

    context 'when authenticated as coach' do
      let(:coach) { create(:user, :coach, organization: organization) }

      it 'returns 403' do
        patch "/api/v1/manager/contracts/#{contract.id}/activate",
              headers: auth_headers(coach)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ── PATCH /api/v1/manager/contracts/:id/terminate ──────────────────────────

  describe 'PATCH /api/v1/manager/contracts/:id/terminate' do
    let(:user)     { create(:user, :admin, organization: organization) }
    let!(:contract) { create_active_contract(player: player) }

    context 'when unauthenticated' do
      it 'returns 401' do
        patch "/api/v1/manager/contracts/#{contract.id}/terminate"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it 'changes the contract status to terminated' do
      patch "/api/v1/manager/contracts/#{contract.id}/terminate",
            headers: auth_headers(user)
      expect(response).to have_http_status(:ok)
      expect(contract.reload.status).to eq('terminated')
    end

    it 'sets terminated_at to today' do
      patch "/api/v1/manager/contracts/#{contract.id}/terminate",
            headers: auth_headers(user)
      expect(contract.reload.terminated_at).to eq(Date.current)
    end

    context 'with an optional reason param' do
      it 'appends the reason to the notes field' do
        patch "/api/v1/manager/contracts/#{contract.id}/terminate",
              params: { reason: 'Performance issues' }.to_json,
              headers: auth_headers(user)
        expect(contract.reload.notes).to include('Performance issues')
      end
    end
  end

  # ── POST /api/v1/manager/contracts/:id/renew ───────────────────────────────

  describe 'POST /api/v1/manager/contracts/:id/renew' do
    let(:user)     { create(:user, :admin, organization: organization) }
    let!(:contract) { create_active_contract(player: player) }

    let(:renewal_params) do
      {
        renewal: {
          start_date:  (Date.current + 1.year + 1.day).to_s,
          end_date:    (Date.current + 2.years).to_s,
          base_salary: 7000
        }
      }
    end

    context 'when unauthenticated' do
      it 'returns 401' do
        post "/api/v1/manager/contracts/#{contract.id}/renew",
             params: renewal_params.to_json,
             headers: { 'Content-Type' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it 'returns 201 and creates a new draft contract' do
      expect do
        post "/api/v1/manager/contracts/#{contract.id}/renew",
             params: renewal_params.to_json,
             headers: auth_headers(user)
      end.to change { Contract.unscoped.count }.by(1)

      expect(response).to have_http_status(:created)
    end

    it 'marks the original contract as renewed' do
      post "/api/v1/manager/contracts/#{contract.id}/renew",
           params: renewal_params.to_json,
           headers: auth_headers(user)
      expect(contract.reload.status).to eq('renewed')
    end

    it 'returns the new contract with status draft' do
      post "/api/v1/manager/contracts/#{contract.id}/renew",
           params: renewal_params.to_json,
           headers: auth_headers(user)
      expect(json_response[:data][:contract][:status]).to eq('draft')
    end

    context 'when authenticated as coach' do
      let(:coach) { create(:user, :coach, organization: organization) }

      it 'returns 403' do
        post "/api/v1/manager/contracts/#{contract.id}/renew",
             params: renewal_params.to_json,
             headers: auth_headers(coach)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'tenant isolation — renewing a contract from another org returns 404' do
      let(:other_org) { create(:organization) }
      let(:other_contract) do
        other_user   = create(:user, :admin, organization: other_org)
        other_player = create(:player, organization: other_org)
        create(:contract, :active, organization: other_org, player: other_player,
               created_by: other_user)
      end

      it 'returns 404' do
        post "/api/v1/manager/contracts/#{other_contract.id}/renew",
             params: renewal_params.to_json,
             headers: auth_headers(user)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
