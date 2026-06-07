# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DraftPlanSerializer do
  let(:organization) { create(:organization) }
  let(:creator) { create(:user, :admin, organization: organization) }
  let(:draft_plan) do
    create(:draft_plan,
           organization: organization,
           created_by: creator,
           updated_by: creator)
  end

  subject(:result) { described_class.render_as_hash(draft_plan) }

  it 'exposes identifier' do
    expect(result[:id]).to eq(draft_plan.id)
  end

  it 'exposes core fields' do
    expect(result).to include(
      :opponent_team, :side, :patch_version, :notes,
      :our_bans, :opponent_bans, :priority_picks, :if_then_scenarios,
      :is_active, :created_at, :updated_at
    )
  end

  describe 'side field' do
    it 'is blue or red' do
      expect(result[:side]).to be_in(%w[blue red])
    end
  end

  describe 'side_display field' do
    it 'is a string' do
      expect(result[:side_display]).to be_a(String)
    end
  end

  describe 'total_scenarios field' do
    it 'is an integer' do
      expect(result[:total_scenarios]).to be_a(Integer)
    end

    it 'is non-negative' do
      expect(result[:total_scenarios]).to be >= 0
    end
  end

  describe 'priority_champions field' do
    it 'is present' do
      expect(result).to have_key(:priority_champions)
    end
  end

  describe 'blind_pick_ready field' do
    it 'is a boolean' do
      expect(result[:blind_pick_ready]).to be_in([true, false])
    end
  end

  describe 'organization association' do
    it 'includes organization id' do
      expect(result[:organization][:id]).to eq(organization.id)
    end
  end

  describe 'created_by association' do
    it 'includes user id' do
      expect(result[:created_by][:id]).to eq(creator.id)
    end

    it 'does not expose password_digest' do
      expect(result[:created_by].keys).not_to include(:password_digest)
    end
  end

  describe 'is_active field' do
    context 'when active' do
      it 'is true' do
        expect(result[:is_active]).to be(true)
      end
    end

    context 'when inactive' do
      let(:draft_plan) do
        create(:draft_plan, :inactive, organization: organization,
                                       created_by: creator, updated_by: creator)
      end

      it 'is false' do
        expect(result[:is_active]).to be(false)
      end
    end
  end
end
