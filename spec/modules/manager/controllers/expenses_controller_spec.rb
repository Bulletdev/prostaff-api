# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Manager::Expenses API', type: :request do
  let(:organization) { create(:organization, tier: 'tier_1_professional') }

  def create_expense(user:, status: 'pending', category: 'travel', amount: 500)
    create(:expense,
           organization: organization,
           created_by:   user,
           status:       status,
           category:     category,
           amount:       amount,
           expense_date: Date.current)
  end

  # ── GET /api/v1/manager/expenses ───────────────────────────────────────────

  describe 'GET /api/v1/manager/expenses' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/manager/expenses'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as owner' do
      let(:user) { create(:user, :owner, organization: organization) }

      before { create_expense(user: user) }

      it 'returns 200' do
        get '/api/v1/manager/expenses', headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when authenticated as admin' do
      let(:user) { create(:user, :admin, organization: organization) }

      before { create_expense(user: user) }

      it 'returns 200 with pagination metadata' do
        get '/api/v1/manager/expenses', headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
        # expenses#index uses render_success paginate(expenses) which wraps in
        # { data: [...], pagination: {...} } at the data level
        expect(json_response[:data][:pagination]).to include(:current_page, :total_count)
      end
    end

    context 'when authenticated as manager' do
      let(:user) { create(:user, :manager, organization: organization) }

      it 'returns 200' do
        get '/api/v1/manager/expenses', headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when authenticated as coach' do
      let(:user) { create(:user, :coach, organization: organization) }

      it 'returns 403' do
        get '/api/v1/manager/expenses', headers: auth_headers(user)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when authenticated as viewer' do
      let(:user) { create(:user, :viewer, organization: organization) }

      it 'returns 403' do
        get '/api/v1/manager/expenses', headers: auth_headers(user)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'tenant isolation' do
      let(:user)      { create(:user, :admin, organization: organization) }
      let(:other_org) { create(:organization) }

      before do
        other_user = create(:user, :admin, organization: other_org)
        create(:expense, organization: other_org, created_by: other_user,
               category: 'travel', amount: 99_999, status: 'pending',
               expense_date: Date.current)
        create_expense(user: user, amount: 100)
      end

      it 'returns only expenses for the authenticated user organization' do
        get '/api/v1/manager/expenses', headers: auth_headers(user)
        amounts = json_response[:data][:data].map { |e| e[:amount].to_f }
        expect(amounts).to all(be < 99_999)
      end
    end
  end

  # ── POST /api/v1/manager/expenses ──────────────────────────────────────────

  describe 'POST /api/v1/manager/expenses' do
    context 'when unauthenticated' do
      it 'returns 401' do
        post '/api/v1/manager/expenses',
             params: { expense: {} }.to_json,
             headers: { 'Content-Type' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as admin' do
      let(:user) { create(:user, :admin, organization: organization) }

      let(:valid_params) do
        {
          expense: {
            category:     'travel',
            description:  'Flight to championship',
            amount:       1200,
            expense_date: Date.current.to_s
          }
        }
      end

      it 'returns 201' do
        post '/api/v1/manager/expenses',
             params: valid_params.to_json,
             headers: auth_headers(user)
        expect(response).to have_http_status(:created)
      end

      it 'creates a pending expense' do
        expect do
          post '/api/v1/manager/expenses',
               params: valid_params.to_json,
               headers: auth_headers(user)
        end.to change { Expense.unscoped.count }.by(1)

        expect(Expense.unscoped.last.status).to eq('pending')
      end

      it 'scopes the expense to the authenticated organization' do
        post '/api/v1/manager/expenses',
             params: valid_params.to_json,
             headers: auth_headers(user)
        expect(Expense.unscoped.last.organization_id).to eq(organization.id)
      end
    end

    context 'when authenticated as coach' do
      let(:user) { create(:user, :coach, organization: organization) }

      it 'returns 403' do
        post '/api/v1/manager/expenses',
             params: { expense: { category: 'travel', amount: 100, expense_date: Date.current.to_s } }.to_json,
             headers: auth_headers(user)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ── GET /api/v1/manager/expenses/salary_summary ────────────────────────────

  describe 'GET /api/v1/manager/expenses/salary_summary' do
    context 'when unauthenticated' do
      it 'returns 401' do
        get '/api/v1/manager/expenses/salary_summary'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as admin' do
      let(:user) { create(:user, :admin, organization: organization) }

      it 'returns 200 with payroll summary fields' do
        get '/api/v1/manager/expenses/salary_summary', headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
        expect(json_response[:data]).to include(:total_monthly_payroll, :player_count, :players)
      end

      it 'total_monthly_payroll is 0 when no active contracts exist' do
        get '/api/v1/manager/expenses/salary_summary', headers: auth_headers(user)
        expect(json_response[:data][:total_monthly_payroll]).to eq(0)
      end
    end

    context 'when authenticated as manager' do
      let(:user) { create(:user, :manager, organization: organization) }

      it 'returns 200' do
        get '/api/v1/manager/expenses/salary_summary', headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when authenticated as coach' do
      let(:user) { create(:user, :coach, organization: organization) }

      it 'returns 403' do
        get '/api/v1/manager/expenses/salary_summary', headers: auth_headers(user)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ── POST /api/v1/manager/expenses/:id/approve ──────────────────────────────

  describe 'POST /api/v1/manager/expenses/:id/approve' do
    let(:user)     { create(:user, :admin, organization: organization) }
    let!(:expense) { create_expense(user: user, status: 'pending') }

    context 'when unauthenticated' do
      it 'returns 401' do
        post "/api/v1/manager/expenses/#{expense.id}/approve"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it 'changes the expense status to approved' do
      post "/api/v1/manager/expenses/#{expense.id}/approve",
           headers: auth_headers(user)
      expect(response).to have_http_status(:ok)
      expect(expense.reload.status).to eq('approved')
    end

    it 'sets approved_by to the current user' do
      post "/api/v1/manager/expenses/#{expense.id}/approve",
           headers: auth_headers(user)
      expect(expense.reload.approved_by_id).to eq(user.id)
    end

    context 'when authenticated as coach' do
      let(:coach) { create(:user, :coach, organization: organization) }

      it 'returns 403' do
        post "/api/v1/manager/expenses/#{expense.id}/approve",
             headers: auth_headers(coach)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'tenant isolation' do
      let(:other_org)     { create(:organization) }
      let(:other_user)    { create(:user, :admin, organization: other_org) }
      let(:other_expense) do
        create(:expense, organization: other_org, created_by: other_user,
               status: 'pending', category: 'travel', amount: 300,
               expense_date: Date.current)
      end

      it 'returns 404 for an expense belonging to another organization' do
        post "/api/v1/manager/expenses/#{other_expense.id}/approve",
             headers: auth_headers(user)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ── POST /api/v1/manager/expenses/:id/mark_paid ────────────────────────────

  describe 'POST /api/v1/manager/expenses/:id/mark_paid' do
    let(:user)     { create(:user, :admin, organization: organization) }
    let!(:expense) { create_expense(user: user, status: 'approved') }

    context 'when unauthenticated' do
      it 'returns 401' do
        post "/api/v1/manager/expenses/#{expense.id}/mark_paid"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it 'changes the expense status to paid' do
      post "/api/v1/manager/expenses/#{expense.id}/mark_paid",
           headers: auth_headers(user)
      expect(response).to have_http_status(:ok)
      expect(expense.reload.status).to eq('paid')
    end

    it 'sets paid_at to today' do
      post "/api/v1/manager/expenses/#{expense.id}/mark_paid",
           headers: auth_headers(user)
      expect(expense.reload.paid_at).to eq(Date.current)
    end

    context 'when authenticated as coach' do
      let(:coach) { create(:user, :coach, organization: organization) }

      it 'returns 403' do
        post "/api/v1/manager/expenses/#{expense.id}/mark_paid",
             headers: auth_headers(coach)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ── POST /api/v1/manager/expenses/:id/reject ───────────────────────────────

  describe 'POST /api/v1/manager/expenses/:id/reject' do
    let(:user)     { create(:user, :admin, organization: organization) }
    let!(:expense) { create_expense(user: user, status: 'pending') }

    context 'when unauthenticated' do
      it 'returns 401' do
        post "/api/v1/manager/expenses/#{expense.id}/reject"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it 'changes the expense status to rejected' do
      post "/api/v1/manager/expenses/#{expense.id}/reject",
           headers: auth_headers(user)
      expect(response).to have_http_status(:ok)
      expect(expense.reload.status).to eq('rejected')
    end

    context 'when authenticated as coach' do
      let(:coach) { create(:user, :coach, organization: organization) }

      it 'returns 403' do
        post "/api/v1/manager/expenses/#{expense.id}/reject",
             headers: auth_headers(coach)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'tenant isolation' do
      let(:other_org)     { create(:organization) }
      let(:other_user)    { create(:user, :admin, organization: other_org) }
      let(:other_expense) do
        create(:expense, organization: other_org, created_by: other_user,
               status: 'pending', category: 'travel', amount: 200,
               expense_date: Date.current)
      end

      it 'returns 404 for an expense from another organization' do
        post "/api/v1/manager/expenses/#{other_expense.id}/reject",
             headers: auth_headers(user)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
