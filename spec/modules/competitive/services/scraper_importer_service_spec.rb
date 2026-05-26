# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScraperImporterService do
  let(:org)     { create(:organization) }
  let(:service) { described_class.new(org) }

  # insert_all bypasses OrganizationScoped default_scope; use unscoped for accurate counts.
  def cm_count
    CompetitiveMatch.unscoped.count
  end

  def match_doc(overrides = {})
    {
      'riot_enriched'  => true,
      'match_id'       => 'CBLOL2026/1',
      'game_number'    => 1,
      'start_time'     => '2026-05-01T18:00:00Z',
      'league'         => 'CBLOL',
      'stage'          => 'Regular Season',
      'patch'          => '14.8',
      'win_team'       => 'paiN Gaming',
      'team1'          => { 'name' => 'paiN Gaming' },
      'team2'          => { 'name' => 'LOUD' },
      'participants'   => [],
      'vod_youtube_id' => nil
    }.merge(overrides)
  end

  describe '#import_batch' do
    context 'with valid enriched matches' do
      it 'imports all records and returns correct stats' do
        matches = [match_doc, match_doc('match_id' => 'CBLOL2026/2', 'game_number' => 2)]

        stats = service.import_batch(matches, our_team: 'paiN Gaming')

        expect(stats[:imported]).to eq(2)
        expect(stats[:errors]).to eq(0)
        expect(cm_count).to eq(2)
      end

      it 'issues at most 3 queries (2 dedup checks + 1 insert)' do
        matches = [match_doc]
        # Force lazy lets to evaluate before the subscribed block so their
        # DB activity (savepoints, INSERT org) is not counted.
        service

        query_count = 0
        counter = ->(*, **) { query_count += 1 }

        ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
          service.import_batch(matches, our_team: 'paiN Gaming')
        end

        # 2 dedup SELECTs + 1 INSERT
        expect(query_count).to be <= 3
      end
    end

    context 'with unenriched matches' do
      it 'skips unenriched and returns correct stat' do
        matches = [match_doc('riot_enriched' => false), match_doc]

        stats = service.import_batch(matches, our_team: 'paiN Gaming')

        expect(stats[:skipped_unenriched]).to eq(1)
        expect(stats[:imported]).to eq(1)
      end
    end

    context 'with not-our-game matches' do
      it 'skips matches where our team is absent' do
        other_match = match_doc('team1' => { 'name' => 'RED Canids' }, 'team2' => { 'name' => 'LOUD' })

        stats = service.import_batch([other_match], our_team: 'paiN Gaming')

        expect(stats[:skipped_not_our_game]).to eq(1)
        expect(stats[:imported]).to eq(0)
      end
    end

    context 'with duplicate matches' do
      it 'skips matches that already exist by external_match_id' do
        create(:competitive_match,
               organization: org,
               external_match_id: 'CBLOL2026/1_1',
               tournament_name: 'CBLOL')

        stats = service.import_batch([match_doc], our_team: 'paiN Gaming')

        expect(stats[:skipped_duplicate]).to eq(1)
        expect(stats[:imported]).to eq(0)
        expect(cm_count).to eq(1)
      end

      it 'deduplicates intra-batch duplicates' do
        same = match_doc
        stats = service.import_batch([same, same], our_team: 'paiN Gaming')

        expect(cm_count).to eq(1)
        expect(stats[:imported]).to eq(1)
      end
    end

    context 'without our_team filter' do
      it 'imports all enriched matches using team1 as ours' do
        stats = service.import_batch([match_doc])

        expect(stats[:imported]).to eq(1)
        expect(CompetitiveMatch.unscoped.first.our_team_name).to eq('paiN Gaming')
      end
    end
  end
end
