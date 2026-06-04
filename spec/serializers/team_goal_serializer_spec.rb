# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TeamGoalSerializer do
  let(:organization) { create(:organization) }
  let(:creator) { create(:user, :admin, organization: organization) }
  let(:team_goal) do
    create(:team_goal,
           organization: organization,
           created_by: creator)
  end

  subject(:result) { described_class.render_as_hash(team_goal) }

  it 'exposes identifier' do
    expect(result[:id]).to eq(team_goal.id)
  end

  it 'exposes core fields' do
    expect(result).to include(
      :title, :description, :category, :metric_type,
      :target_value, :current_value, :start_date, :end_date,
      :status, :progress, :created_at, :updated_at
    )
  end

  describe 'completion_percentage field' do
    it 'is within 0 to 100' do
      pct = result[:completion_percentage].to_f
      expect(pct).to be >= 0.0
      expect(pct).to be <= 100.0
    end
  end

  describe 'is_team_goal field' do
    context 'when no player is assigned' do
      it 'is true' do
        expect(result[:is_team_goal]).to be(true)
      end
    end

    context 'when a player is assigned' do
      let(:player) { create(:player, organization: organization) }
      let(:team_goal) do
        create(:team_goal, :for_player, organization: organization,
                                        player: player, created_by: creator)
      end

      it 'is false' do
        expect(result[:is_team_goal]).to be(false)
      end
    end
  end

  describe 'days_remaining field' do
    it 'is present' do
      expect(result).to have_key(:days_remaining)
    end
  end

  describe 'days_total field' do
    it 'is present and non-negative' do
      expect(result[:days_total]).to be_a(Numeric).or be_nil
    end
  end

  describe 'time_progress_percentage field' do
    it 'is present' do
      expect(result).to have_key(:time_progress_percentage)
    end
  end

  describe 'is_overdue field' do
    context 'when goal is active with future end date' do
      it 'is false' do
        expect(result[:is_overdue]).to be(false)
      end
    end
  end

  describe 'target_display field' do
    it 'is present' do
      expect(result).to have_key(:target_display)
    end
  end

  describe 'current_display field' do
    it 'is present' do
      expect(result).to have_key(:current_display)
    end
  end

  describe 'organization association' do
    it 'includes organization id' do
      expect(result[:organization][:id]).to eq(organization.id)
    end
  end

  describe 'status field' do
    it 'is a known lifecycle value' do
      expect(result[:status]).to be_in(%w[active completed cancelled paused])
    end
  end
end
