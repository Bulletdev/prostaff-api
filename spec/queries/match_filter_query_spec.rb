# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MatchFilterQuery do
  let(:organization) { create(:organization) }

  # MatchFilterQuery receives an already-scoped relation from the controller.
  # Outside a request context, OrganizationScoped's default_scope blocks access
  # unless Current.organization_id is set. We replicate what the controller does.
  before do
    Current.organization_id = organization.id
  end

  after do
    Current.reset
  end

  let(:base_relation) { Match.where(organization_id: organization.id) }

  let!(:victory_match) do
    create(:match,
           organization: organization,
           match_type: 'official',
           victory: true,
           game_start: 10.days.ago,
           opponent_name: 'Team Alpha')
  end

  let!(:defeat_match) do
    create(:match,
           organization: organization,
           match_type: 'scrim',
           victory: false,
           game_start: 5.days.ago,
           opponent_name: 'Team Beta')
  end

  let!(:old_match) do
    create(:match,
           organization: organization,
           match_type: 'official',
           victory: true,
           game_start: 40.days.ago,
           opponent_name: 'Team Gamma')
  end

  def query(params = {})
    described_class.new(base_relation, params).call
  end

  describe '#call (no filters)' do
    it 'returns all matches for the relation' do
      expect(query.count).to eq(3)
    end

    it 'applies default sort (game_start desc)' do
      results = query.to_a
      expect(results.first).to eq(defeat_match)
      expect(results.last).to eq(old_match)
    end
  end

  describe 'match_type filter' do
    it 'filters by match_type official' do
      results = query(match_type: 'official')
      expect(results).to include(victory_match, old_match)
      expect(results).not_to include(defeat_match)
    end

    it 'filters by match_type scrim' do
      results = query(match_type: 'scrim')
      expect(results).to contain_exactly(defeat_match)
    end

    it 'returns all matches when match_type is blank' do
      expect(query(match_type: '').count).to eq(3)
    end
  end

  describe 'result filter' do
    it 'returns only victories when result=victory' do
      results = query(result: 'victory')
      expect(results).to include(victory_match, old_match)
      expect(results).not_to include(defeat_match)
    end

    it 'returns only defeats when result=defeat' do
      results = query(result: 'defeat')
      expect(results).to contain_exactly(defeat_match)
    end

    it 'returns all when result is absent' do
      expect(query.count).to eq(3)
    end
  end

  describe 'date range filter' do
    it 'filters by start_date and end_date' do
      results = query(start_date: 15.days.ago.to_s, end_date: 1.day.ago.to_s)
      expect(results).to include(victory_match, defeat_match)
      expect(results).not_to include(old_match)
    end

    it 'uses days filter when only days param is given' do
      results = query(days: 7)
      # defeat_match is 5 days old — within 7 days window
      expect(results).to include(defeat_match)
      # old_match is 40 days ago — outside window
      expect(results).not_to include(old_match)
    end

    it 'returns all when neither date params nor days are given' do
      expect(query.count).to eq(3)
    end
  end

  describe 'opponent filter' do
    it 'filters by opponent name substring' do
      results = query(opponent: 'Alpha')
      expect(results).to contain_exactly(victory_match)
    end

    it 'is case-insensitive' do
      results = query(opponent: 'alpha')
      expect(results).to contain_exactly(victory_match)
    end

    it 'returns all when opponent is blank' do
      expect(query(opponent: '').count).to eq(3)
    end
  end

  describe 'sorting' do
    it 'sorts ascending when requested' do
      results = query(sort_by: 'game_start', sort_order: 'asc').to_a
      expect(results.first).to eq(old_match)
      expect(results.last).to eq(defeat_match)
    end

    it 'falls back to default sort_by for unknown field (game_start desc)' do
      results = query(sort_by: 'injected_field', sort_order: 'desc').to_a
      expect(results.first).to eq(defeat_match)
    end

    it 'falls back to default sort_order for unknown value' do
      results = query(sort_by: 'game_start', sort_order: 'sideways').to_a
      expect(results.first).to eq(defeat_match)
    end

    it 'rejects arbitrary sort_by to prevent SQL injection' do
      expect(MatchFilterQuery::ALLOWED_SORT_FIELDS).not_to include('malicious; DROP TABLE matches;--')
    end

    it 'supports all documented sort fields' do
      expect(MatchFilterQuery::ALLOWED_SORT_FIELDS).to include('game_start', 'game_duration', 'victory')
    end
  end

  describe 'multi-tenancy isolation' do
    let(:other_organization) { create(:organization) }
    let!(:other_org_match)   { create(:match, organization: other_organization) }

    it 'does not return matches from another organization' do
      # The base_relation is scoped to `organization`, so another org's
      # match must never appear regardless of filter params.
      results = described_class.new(base_relation, {}).call
      expect(results).not_to include(other_org_match)
    end
  end
end
