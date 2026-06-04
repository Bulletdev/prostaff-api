# frozen_string_literal: true

require 'rails_helper'

# AvailabilityWindow includes OrganizationScoped (default_scope via Current.organization_id).
# We use Current.skip_organization_scope = true to bypass the scope when creating fixtures
# for orgs outside the current organization context.

RSpec.describe MatchSuggestionService do
  let(:organization) { create(:organization, region: 'BR', subscription_plan: 'amateur') }

  # Helper: create availability windows for other orgs bypassing OrganizationScoped default_scope
  def create_window_for(org, **attrs)
    Current.skip_organization_scope = true
    window = create(:availability_window, organization: org, active: true,
                    game: 'league_of_legends', expires_at: nil, **attrs)
    Current.skip_organization_scope = false
    window
  end

  after do
    Current.skip_organization_scope = false
  end

  describe '#suggestions' do
    context 'when there are other orgs with active availability windows' do
      let(:other_org) { create(:organization, region: 'BR', subscription_plan: 'amateur') }

      before { create_window_for(other_org) }

      it 'returns a non-empty list of suggestions' do
        expect(described_class.new(organization).suggestions).not_to be_empty
      end

      it 'returns suggestions with the expected keys' do
        suggestion = described_class.new(organization).suggestions.first
        expect(suggestion).to include(:score, :organization, :availability_window)
      end

      it 'returns suggestions sorted by score descending' do
        scores = described_class.new(organization).suggestions.map { |s| s[:score] }
        expect(scores).to eq(scores.sort.reverse)
      end

      it 'does not include the requesting organization itself' do
        create_window_for(organization)
        org_ids = described_class.new(organization).suggestions.map { |s| s[:organization][:id] }
        expect(org_ids).not_to include(organization.id)
      end

      it 'returns organization data with expected fields' do
        org_data = described_class.new(organization).suggestions.first[:organization]
        expect(org_data).to include(:id, :name, :region, :tier, :avg_tier)
        expect(org_data).to include(:scrims_won, :scrims_lost, :total_scrims)
      end

      it 'returns availability_window data with expected fields' do
        window_data = described_class.new(organization).suggestions.first[:availability_window]
        expect(window_data).to include(:id, :day_of_week, :start_hour, :end_hour, :timezone)
      end
    end

    context 'when all windows belong to the requesting organization' do
      before { create_window_for(organization) }

      it 'returns an empty list' do
        expect(described_class.new(organization).suggestions).to be_empty
      end
    end

    context 'when no active windows exist (all inactive)' do
      let(:other_org) { create(:organization, region: 'BR') }

      before do
        Current.skip_organization_scope = true
        create(:availability_window, :inactive, organization: other_org,
               game: 'league_of_legends')
        Current.skip_organization_scope = false
      end

      it 'returns an empty list' do
        expect(described_class.new(organization).suggestions).to be_empty
      end
    end

    context 'when limit is specified' do
      before do
        3.times do
          org = create(:organization, region: 'BR')
          create_window_for(org)
        end
      end

      it 'respects the limit parameter' do
        expect(described_class.new(organization, limit: 2).suggestions.size).to be <= 2
      end
    end

    context 'region matching scores same-region orgs higher' do
      let(:br_org) { create(:organization, region: 'BR') }
      let(:na_org) { create(:organization, region: 'NA') }

      before do
        create_window_for(br_org, region: 'BR')
        create_window_for(na_org, region: 'NA')
      end

      it 'scores same-region orgs higher than different-region' do
        suggestions = described_class.new(organization).suggestions # organization.region = 'BR'

        br_suggestion = suggestions.find { |s| s[:organization][:id] == br_org.id }
        na_suggestion = suggestions.find { |s| s[:organization][:id] == na_org.id }

        expect(br_suggestion[:score]).to be > na_suggestion[:score]
      end
    end

    context 'game filter' do
      let(:other_org)   { create(:organization) }
      let(:valorant_org) { create(:organization) }

      before do
        create_window_for(other_org)
        Current.skip_organization_scope = true
        create(:availability_window, organization: valorant_org, active: true,
               game: 'valorant', expires_at: nil)
        Current.skip_organization_scope = false
      end

      it 'only returns windows matching the specified game' do
        service = described_class.new(organization, game: 'league_of_legends')
        org_ids = service.suggestions.map { |s| s[:organization][:id] }
        expect(org_ids).to include(other_org.id)
        expect(org_ids).not_to include(valorant_org.id)
      end
    end
  end

  describe '#available_now' do
    context 'when there are orgs with windows available at the current time' do
      let(:other_org)    { create(:organization, region: 'BR') }
      let(:current_hour) { Time.current.hour }
      let(:current_day)  { Time.current.wday }

      before do
        start_h = [current_hour - 1, 0].max
        end_h   = [current_hour + 1, 23].min
        # Skip hours at boundary where start >= end is possible
        next if start_h >= end_h

        Current.skip_organization_scope = true
        create(:availability_window,
               organization: other_org,
               active: true,
               day_of_week: current_day,
               start_hour: start_h,
               end_hour: end_h,
               game: 'league_of_legends',
               expires_at: nil)
        Current.skip_organization_scope = false
      end

      it 'does not include the requesting organization' do
        create_window_for(organization)
        org_ids = described_class.new(organization).available_now.map { |s| s[:organization][:id] }
        expect(org_ids).not_to include(organization.id)
      end

      it 'returns an array of suggestions' do
        expect(described_class.new(organization).available_now).to be_an(Array)
      end
    end
  end
end
