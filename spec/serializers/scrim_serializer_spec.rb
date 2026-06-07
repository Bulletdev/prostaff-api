# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScrimSerializer do
  let(:organization) { create(:organization) }
  let(:scrim) { create(:scrim, organization: organization) }

  subject(:result) { described_class.new(scrim).as_json }

  it 'exposes identifier' do
    expect(result[:id]).to eq(scrim.id)
  end

  it 'exposes core fields' do
    expect(result).to include(
      :scheduled_at, :scrim_type, :focus_area, :draft_type,
      :games_planned, :games_completed, :completion_percentage,
      :status, :is_confidential, :visibility,
      :created_at, :updated_at
    )
  end

  describe 'win_rate field' do
    it 'is present' do
      expect(result).to have_key(:win_rate)
    end

    context 'when completed with game results' do
      let(:scrim) { create(:scrim, :completed, organization: organization) }

      it 'is within 0 to 100' do
        rate = result[:win_rate].to_f
        expect(rate).to be >= 0.0
        expect(rate).to be <= 100.0
      end
    end
  end

  describe 'opponent_team field' do
    context 'when no opponent team is linked' do
      it 'is nil' do
        expect(result[:opponent_team]).to be_nil
      end
    end

    context 'when an opponent team is linked' do
      let(:opponent_team) { create(:opponent_team) }
      let(:scrim) { create(:scrim, organization: organization, opponent_team: opponent_team) }

      it 'includes id, name, and tag' do
        expect(result[:opponent_team]).to include(:id, :name, :tag)
      end

      it 'includes tier and region' do
        expect(result[:opponent_team]).to include(:tier, :region)
      end
    end
  end

  describe 'detailed mode' do
    subject(:detailed) { described_class.new(scrim, detailed: true).as_json }

    it 'includes post_game_notes' do
      expect(detailed).to have_key(:post_game_notes)
    end

    it 'includes game_results' do
      expect(detailed).to have_key(:game_results)
    end

    it 'includes objectives' do
      expect(detailed).to have_key(:objectives)
    end

    it 'includes head_to_head' do
      expect(detailed).to have_key(:head_to_head)
    end
  end

  describe 'calendar_view mode' do
    subject(:calendar) { described_class.new(scrim, calendar_view: true).as_json }

    it 'includes title, start, end, and color' do
      expect(calendar).to include(:title, :start, :end, :color)
    end
  end

  describe 'cross-org isolation' do
    let(:other_org) { create(:organization) }
    let(:other_scrim) { create(:scrim, organization: other_org) }

    it 'serializes its own organization_id' do
      expect(result[:organization_id]).to eq(organization.id)
      expect(result[:organization_id]).not_to eq(other_org.id)
    end
  end
end
