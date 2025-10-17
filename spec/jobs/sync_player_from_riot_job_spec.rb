require 'rails_helper'

RSpec.describe SyncPlayerFromRiotJob, type: :job do
  let(:organization) { create(:organization) }
  let(:player) { create(:player, organization: organization, summoner_name: 'TestPlayer#BR1', riot_puuid: nil) }

  before do
    # Allow ENV to be stubbed without breaking Database Cleaner
    allow(ENV).to receive(:[]).and_call_original
  end

  describe '#perform' do
    context 'when player has no Riot info' do
      it 'sets error status and logs error' do
        player_no_info = build(:player, organization: organization, riot_puuid: nil)
        player_no_info.summoner_name = nil
        player_no_info.save(validate: false)

        expect(Rails.logger).to receive(:error).with("Player #{player_no_info.id} missing Riot info")

        described_class.new.perform(player_no_info.id)

        player_no_info.reload
        expect(player_no_info.sync_status).to eq('error')
        expect(player_no_info.last_sync_at).to be_present
      end
    end

    context 'when Riot API key is not configured' do
      it 'sets error status and logs error' do
        allow(ENV).to receive(:[]).with('RIOT_API_KEY').and_return(nil)

        expect(Rails.logger).to receive(:error).with('Riot API key not configured')

        described_class.new.perform(player.id)

        player.reload
        expect(player.sync_status).to eq('error')
        expect(player.last_sync_at).to be_present
      end
    end

    context 'when sync is successful' do
      let(:summoner_data) do
        {
          'puuid' => 'test-puuid-123',
          'id' => 'test-summoner-id',
          'summonerLevel' => 100,
          'profileIconId' => 1234
        }
      end

      let(:ranked_data) do
        [
          {
            'queueType' => 'RANKED_SOLO_5x5',
            'tier' => 'DIAMOND',
            'rank' => 'II',
            'leaguePoints' => 75,
            'wins' => 120,
            'losses' => 80
          },
          {
            'queueType' => 'RANKED_FLEX_SR',
            'tier' => 'PLATINUM',
            'rank' => 'I',
            'leaguePoints' => 50
          }
        ]
      end

      before do
        allow(ENV).to receive(:[]).with('RIOT_API_KEY').and_return('test-api-key')
      end

      it 'syncs player data from Riot API' do
        job = described_class.new
        allow(job).to receive(:fetch_summoner_by_name).and_return(summoner_data)
        allow(job).to receive(:fetch_ranked_stats).and_return(ranked_data)

        expect(Rails.logger).to receive(:info).with("Successfully synced player #{player.id} from Riot API")

        job.perform(player.id)

        player.reload
        expect(player.riot_puuid).to eq('test-puuid-123')
        expect(player.riot_summoner_id).to eq('test-summoner-id')
        expect(player.summoner_level).to eq(100)
        expect(player.profile_icon_id).to eq(1234)
        expect(player.solo_queue_tier).to eq('DIAMOND')
        expect(player.solo_queue_rank).to eq('II')
        expect(player.solo_queue_lp).to eq(75)
        expect(player.solo_queue_wins).to eq(120)
        expect(player.solo_queue_losses).to eq(80)
        expect(player.flex_queue_tier).to eq('PLATINUM')
        expect(player.flex_queue_rank).to eq('I')
        expect(player.flex_queue_lp).to eq(50)
        expect(player.sync_status).to eq('success')
        expect(player.last_sync_at).to be_present
      end

      it 'uses player region when available' do
        player.update(region: 'NA1')
        job = described_class.new

        expect(job).to receive(:fetch_summoner_by_name).with(
          player.summoner_name,
          'na1',
          'test-api-key'
        ).and_return(summoner_data)

        allow(job).to receive(:fetch_ranked_stats).and_return(ranked_data)

        job.perform(player.id)
      end

      it 'defaults to BR1 when region is not set' do
        player.update(region: nil)
        job = described_class.new

        expect(job).to receive(:fetch_summoner_by_name).with(
          player.summoner_name,
          'br1',
          'test-api-key'
        ).and_return(summoner_data)

        allow(job).to receive(:fetch_ranked_stats).and_return(ranked_data)

        job.perform(player.id)
      end
    end

    context 'when sync fails' do
      before do
        allow(ENV).to receive(:[]).with('RIOT_API_KEY').and_return('test-api-key')
      end

      it 'sets error status and logs error' do
        job = described_class.new
        allow(job).to receive(:fetch_summoner_by_name).and_raise(StandardError.new('API Error'))

        expect(Rails.logger).to receive(:error).with("Failed to sync player #{player.id}: API Error")
        expect(Rails.logger).to receive(:error).with(anything) # backtrace

        job.perform(player.id)

        player.reload
        expect(player.sync_status).to eq('error')
        expect(player.last_sync_at).to be_present
      end
    end

    context 'when player has PUUID' do
      let(:player_with_puuid) do
        create(:player, organization: organization, riot_puuid: 'existing-puuid')
      end

      let(:summoner_data) do
        {
          'puuid' => 'existing-puuid',
          'id' => 'test-summoner-id',
          'summonerLevel' => 100,
          'profileIconId' => 1234
        }
      end

      before do
        allow(ENV).to receive(:[]).with('RIOT_API_KEY').and_return('test-api-key')
      end

      it 'fetches summoner by PUUID instead of name' do
        job = described_class.new

        expect(job).to receive(:fetch_summoner_by_puuid).with(
          'existing-puuid',
          'br1',
          'test-api-key'
        ).and_return(summoner_data)

        allow(job).to receive(:fetch_ranked_stats).and_return([])

        job.perform(player_with_puuid.id)
      end
    end
  end
end
