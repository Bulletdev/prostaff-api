# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScrimAnalyticsService do
  let(:organization) { create(:organization, tier: 'tier_2_semi_pro') }
  let(:opponent)     { create(:opponent_team) }
  let(:service)      { described_class.new(organization) }

  # OrganizationScoped default_scope filters out records when Current.organization_id is nil.
  # Set it for the duration of each example so Scrim queries return data.
  before do
    Current.organization_id = organization.id
  end

  after do
    Current.reset
  end

  describe '#overall_stats' do
    context 'when the organization has no scrims' do
      it 'returns zeros without raising an exception' do
        result = service.overall_stats

        expect(result).to be_a(Hash)
        expect(result[:total_scrims]).to eq(0)
        expect(result[:total_games]).to eq(0)
        expect(result[:wins]).to eq(0)
        expect(result[:losses]).to eq(0)
      end

      it 'returns win_rate of 0' do
        result = service.overall_stats

        expect(result[:win_rate]).to eq(0)
      end

      it 'returns a completion_rate of 0' do
        result = service.overall_stats

        expect(result[:completion_rate]).to eq(0)
      end
    end

    context 'when the organization has scrims with results' do
      before do
        create(:scrim, :past, organization: organization,
               games_planned: 3,
               games_completed: 2,
               game_results: [{ 'victory' => true }, { 'victory' => false }])
        create(:scrim, :past, organization: organization,
               games_planned: 3,
               games_completed: 2,
               game_results: [{ 'victory' => true }, { 'victory' => true }])
      end

      it 'returns win_rate between 0 and 100' do
        result = service.overall_stats

        expect(result[:win_rate]).to be_between(0.0, 100.0)
      end

      it 'counts wins correctly' do
        result = service.overall_stats

        # 3 wins, 1 loss across 4 games
        expect(result[:wins]).to eq(3)
        expect(result[:losses]).to eq(1)
      end

      it 'counts total_scrims within the date range' do
        result = service.overall_stats(date_range: 30.days)

        expect(result[:total_scrims]).to eq(2)
      end

      it 'does not include scrims outside the date range' do
        old_scrim = create(:scrim, organization: organization,
                           scheduled_at: 60.days.ago,
                           games_planned: 3,
                           game_results: [{ 'victory' => true }])
        # Force created_at to be outside the 30-day window
        old_scrim.update_column(:created_at, 60.days.ago)

        # Use a narrow range so the old scrim is excluded
        result = service.overall_stats(date_range: 30.days)

        expect(result[:total_scrims]).to eq(2)
      end

      it 'returns focus_areas as a Hash' do
        result = service.overall_stats

        expect(result[:focus_areas]).to be_a(Hash)
      end
    end

    context 'win_rate domain invariant' do
      it 'is never negative' do
        result = service.overall_stats

        expect(result[:win_rate]).to be >= 0
      end

      it 'is never above 100' do
        create(:scrim, :past, organization: organization,
               game_results: Array.new(10) { { 'victory' => true } },
               games_completed: 10,
               games_planned: 10)

        result = service.overall_stats

        expect(result[:win_rate]).to be <= 100
      end
    end
  end

  describe '#stats_by_opponent' do
    context 'when scrims have no opponent team' do
      before { create(:scrim, :past, organization: organization, opponent_team: nil) }

      it 'excludes entries without an opponent' do
        result = service.stats_by_opponent

        expect(result).to be_an(Array)
        expect(result).to be_empty
      end
    end

    context 'when scrims have opponent teams' do
      before do
        create(:scrim, :past, organization: organization, opponent_team: opponent,
               game_results: [{ 'victory' => true }], games_completed: 1)
        create(:scrim, :past, organization: organization, opponent_team: opponent,
               game_results: [{ 'victory' => false }], games_completed: 1)
      end

      it 'groups results by opponent' do
        result = service.stats_by_opponent

        expect(result.size).to eq(1)
        entry = result.first
        expect(entry[:opponent_team][:id]).to eq(opponent.id)
        expect(entry[:total_scrims]).to eq(2)
      end

      it 'returns win_rate between 0 and 100 for each opponent' do
        result = service.stats_by_opponent

        result.each do |entry|
          expect(entry[:win_rate]).to be_between(0.0, 100.0)
        end
      end

      it 'does not leak scrims from another organization' do
        other_org    = create(:organization, tier: 'tier_2_semi_pro')
        other_scrim  = create(:scrim, :past, organization: other_org, opponent_team: opponent,
                              game_results: [{ 'victory' => true }], games_completed: 1)

        result = service.stats_by_opponent
        total_games = result.find { |e| e[:opponent_team][:id] == opponent.id }&.dig(:total_games)

        # other_org's scrim game is NOT counted in organization's stats
        expect(total_games).to eq(2)

        _ = other_scrim # suppress unused variable warning
      end
    end
  end

  describe '#stats_by_focus_area' do
    context 'when no scrims have a focus_area' do
      before { create(:scrim, organization: organization, focus_area: nil) }

      it 'returns an empty hash' do
        result = service.stats_by_focus_area

        expect(result).to be_a(Hash)
        expect(result).to be_empty
      end
    end

    context 'when scrims have focus areas' do
      before do
        create(:scrim, :past, organization: organization,
               focus_area: 'laning',
               games_planned: 3,
               games_completed: 1,
               game_results: [{ 'victory' => true }])
        create(:scrim, :past, organization: organization,
               focus_area: 'teamfight',
               games_planned: 3,
               games_completed: 1,
               game_results: [{ 'victory' => false }])
      end

      it 'returns a hash keyed by focus area' do
        result = service.stats_by_focus_area

        expect(result.keys).to include('laning', 'teamfight')
      end

      it 'each entry has required keys' do
        result = service.stats_by_focus_area

        result.each_value do |stats|
          expect(stats).to include(:total_scrims, :total_games, :win_rate, :avg_completion)
        end
      end

      it 'win_rate is between 0 and 100 for each focus area' do
        result = service.stats_by_focus_area

        result.each_value do |stats|
          expect(stats[:win_rate]).to be_between(0.0, 100.0)
        end
      end
    end
  end

  describe '#success_patterns' do
    context 'when there are no winning scrims' do
      before { create(:scrim, :past, organization: organization, game_results: []) }

      it 'returns a hash without raising' do
        result = service.success_patterns

        expect(result).to be_a(Hash)
      end

      it 'includes expected keys' do
        result = service.success_patterns

        expect(result).to include(:best_focus_areas, :best_time_of_day,
                                  :optimal_games_count, :common_objectives)
      end
    end
  end

  describe '#improvement_trends' do
    context 'when fewer than 10 scrims exist' do
      before { create_list(:scrim, 5, organization: organization) }

      it 'returns empty hash when not enough data' do
        result = service.improvement_trends

        expect(result).to eq({})
      end
    end

    context 'when at least 10 scrims exist' do
      before do
        create_list(:scrim, 12, :past, organization: organization,
                   game_results: [{ 'victory' => true }],
                   games_completed: 1)
      end

      it 'returns improvement metrics' do
        result = service.improvement_trends

        expect(result).to include(:initial_win_rate, :recent_win_rate, :improvement_delta)
      end

      it 'win rates are between 0 and 100' do
        result = service.improvement_trends

        expect(result[:initial_win_rate]).to be_between(0.0, 100.0)
        expect(result[:recent_win_rate]).to be_between(0.0, 100.0)
      end
    end
  end
end
