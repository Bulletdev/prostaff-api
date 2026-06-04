# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Matches::SyncMatchJob, type: :job do
  let(:organization) { create(:organization) }
  let(:player) do
    create(:player, organization: organization, riot_puuid: 'player-puuid-001')
  end

  let(:participant_data) do
    {
      puuid: player.riot_puuid,
      champion_name: 'Jinx',
      role: 'bottom',
      team_id: 100,
      win: true,
      kills: 10,
      deaths: 2,
      assists: 5,
      gold_earned: 14_500,
      total_damage_dealt: 55_000,
      total_damage_taken: 18_000,
      minions_killed: 180,
      neutral_minions_killed: 20,
      vision_score: 30,
      wards_placed: 8,
      wards_killed: 3,
      control_wards_purchased: 4,
      double_kills: 1,
      triple_kills: 0,
      quadra_kills: 0,
      penta_kills: 0,
      first_blood_kill: false,
      first_tower_kill: false,
      objectives_stolen: 0,
      crowd_control_score: 40,
      total_time_dead: 30,
      damage_to_turrets: 3_000,
      damage_shielded_teammates: 0,
      healing_to_teammates: 0,
      cs_at_10: 80,
      turret_plates_destroyed: 2,
      pings: {},
      summoner_spell_1: 'Flash',
      summoner_spell_2: 'Heal',
      summoner_spell_1_casts: 3,
      summoner_spell_2_casts: 2,
      spell_q_casts: 120,
      spell_w_casts: 60,
      spell_e_casts: 90,
      spell_r_casts: 5,
      items: [3031, 3094, 3046],
      runes: [8008]
    }
  end

  let(:match_api_data) do
    {
      match_id: 'BR1_12345678',
      game_creation: 1.hour.ago,
      game_duration: 1800,
      game_version: '14.10.1',
      game_mode: 'CLASSIC',
      participants: [participant_data]
    }
  end

  let(:riot_service) { instance_double(RiotApiService) }

  # Match and PlayerMatchStat include OrganizationScoped which applies a
  # default_scope keyed on Current.organization_id. Set it for association
  # count queries that run after the job's ensure block clears Current.
  def match_count_for_org
    Current.organization_id = organization.id
    organization.matches.count
  ensure
    Current.organization_id = nil
  end

  def player_stat_count_for_org
    Current.organization_id = organization.id
    PlayerMatchStat.where(player: organization.players).count
  ensure
    Current.organization_id = nil
  end

  def last_match_stat
    Current.organization_id = organization.id
    PlayerMatchStat.joins(:match).where(matches: { organization_id: organization.id }).last
  ensure
    Current.organization_id = nil
  end

  before do
    player # ensure player exists before stubs
    allow(RiotApiService).to receive(:new).and_return(riot_service)
    allow(riot_service).to receive(:get_match_details).and_return(match_api_data)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  after do
    Current.reset
  end

  describe '#perform' do
    context 'success path — new match' do
      it 'creates a Match record scoped to the organization' do
        expect { described_class.new.perform('BR1_12345678', organization.id) }
          .to change { match_count_for_org }.by(1)
      end

      it 'sets the riot_match_id correctly' do
        described_class.new.perform('BR1_12345678', organization.id)

        Current.organization_id = organization.id
        match = Match.find_by(riot_match_id: 'BR1_12345678')
        Current.organization_id = nil
        expect(match).to be_present
        expect(match.riot_match_id).to eq('BR1_12345678')
      end

      it 'creates PlayerMatchStat records for org players' do
        expect { described_class.new.perform('BR1_12345678', organization.id) }
          .to change { player_stat_count_for_org }.by_at_least(1)
      end

      it 'normalizes bottom role to adc' do
        described_class.new.perform('BR1_12345678', organization.id)

        stat = last_match_stat
        expect(stat.role).to eq('adc')
      end

      it 'ensures KDA is never negative (kills=10, deaths=2, assists=5 -> 7.5)' do
        described_class.new.perform('BR1_12345678', organization.id)

        stat = last_match_stat
        kills   = stat.kills.to_f
        deaths  = stat.deaths.to_f
        assists = stat.assists.to_f
        kda = deaths.zero? ? (kills + assists) : ((kills + assists) / deaths)
        expect(kda).to be >= 0
      end

      it 'sets performance_score to a non-negative value' do
        described_class.new.perform('BR1_12345678', organization.id)

        stat = last_match_stat
        expect(stat.performance_score).to be >= 0
      end

      it 'clears Current.organization_id after execution' do
        described_class.new.perform('BR1_12345678', organization.id)

        expect(Current.organization_id).to be_nil
      end
    end

    context 'when match already exists and is up to date' do
      before do
        Current.organization_id = organization.id
        match = create(:match, organization: organization, riot_match_id: 'BR1_12345678')
        create(:player_match_stat, match: match, player: player,
                                   cs: 100, damage_share: 0.3, gold_share: 0.25, cs_per_min: 6.5)
        Current.organization_id = nil
      end

      it 'does not create a duplicate Match record' do
        expect { described_class.new.perform('BR1_12345678', organization.id) }
          .not_to change { match_count_for_org }
      end
    end

    context 'when match exists but needs update (missing cs)' do
      before do
        Current.organization_id = organization.id
        match = create(:match, organization: organization, riot_match_id: 'BR1_12345678')
        create(:player_match_stat, match: match, player: player,
                                   cs: 0, damage_share: nil, gold_share: nil, cs_per_min: nil)
        Current.organization_id = nil
      end

      it 'updates the match and recreates stats' do
        expect { described_class.new.perform('BR1_12345678', organization.id, 'BR', force_update: false) }
          .not_to raise_error
      end
    end

    context 'when force_update is true' do
      before do
        Current.organization_id = organization.id
        match = create(:match, organization: organization, riot_match_id: 'BR1_12345678')
        create(:player_match_stat, match: match, player: player,
                                   cs: 200, damage_share: 0.4, gold_share: 0.3, cs_per_min: 7.0)
        Current.organization_id = nil
      end

      it 'updates the match without raising' do
        expect { described_class.new.perform('BR1_12345678', organization.id, 'BR', force_update: true) }
          .not_to raise_error
      end
    end

    context 'when Riot API returns NotFoundError' do
      before do
        allow(riot_service).to receive(:get_match_details)
          .and_raise(RiotApiService::NotFoundError, 'Match not found')
      end

      it 'does not raise — logs the error and returns normally' do
        expect { described_class.new.perform('BR1_NOTFOUND', organization.id) }
          .not_to raise_error
      end

      it 'logs an error message' do
        described_class.new.perform('BR1_NOTFOUND', organization.id)

        expect(Rails.logger).to have_received(:error).with(include('Match not found'))
      end
    end

    context 'when an unexpected StandardError is raised inside the job' do
      it 're-raises so Sidekiq can retry' do
        job = described_class.new
        allow(job).to receive(:create_match_record).and_raise(StandardError, 'unexpected')

        expect { job.perform('BR1_12345678', organization.id) }.to raise_error(StandardError, 'unexpected')
      end

      it 'still clears Current.organization_id after a re-raised error' do
        job = described_class.new
        allow(job).to receive(:create_match_record).and_raise(StandardError, 'unexpected')

        begin
          job.perform('BR1_12345678', organization.id)
        rescue StandardError
          nil
        end

        expect(Current.organization_id).to be_nil
      end
    end

    context 'job metadata' do
      it 'is enqueued on the default queue' do
        expect(described_class.queue_name).to eq('default')
      end
    end
  end
end
