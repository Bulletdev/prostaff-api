# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DataDragonService do
  let(:service) { described_class.new }
  let(:version) { '14.10.1' }

  # DDragon URLs use a versioned CDN path — stub the version endpoint first so
  # the service resolves the current patch before fetching champion data.
  let(:versions_url) { 'https://ddragon.leagueoflegends.com/api/versions.json' }
  let(:champion_url) do
    "https://ddragon.leagueoflegends.com/cdn/#{version}/data/en_US/champion.json"
  end

  let(:champion_payload) do
    {
      'type' => 'champion',
      'data' => {
        'Jinx'    => { 'key' => '222', 'name' => 'Jinx',    'id' => 'Jinx' },
        'Lux'     => { 'key' => '99',  'name' => 'Lux',     'id' => 'Lux' },
        'LeeSin'  => { 'key' => '64',  'name' => 'Lee Sin',  'id' => 'LeeSin' },
        'Wukong'  => { 'key' => '62',  'name' => 'Wukong',  'id' => 'Wukong' },
        'KhaZix'  => { 'key' => '121', 'name' => "Kha'Zix",  'id' => 'KhaZix' }
      }
    }.to_json
  end

  before do
    stub_request(:get, versions_url)
      .to_return(status: 200, body: [version, '14.9.1', '14.8.1'].to_json,
                 headers: { 'Content-Type' => 'application/json' })

    stub_request(:get, champion_url)
      .to_return(status: 200, body: champion_payload,
                 headers: { 'Content-Type' => 'application/json' })

    # Clear Rails cache before each example so stubs are always exercised.
    Rails.cache.clear
    service.instance_variable_set(:@latest_version, nil)
  end

  describe '#latest_version' do
    it 'returns the first entry from the versions endpoint' do
      expect(service.latest_version).to eq(version)
    end

    it 'caches the result so the HTTP call is made only once' do
      service.latest_version
      service.latest_version
      expect(WebMock).to have_requested(:get, versions_url).once
    end

    context 'when the versions endpoint fails' do
      before do
        stub_request(:get, versions_url).to_return(status: 503)
      end

      it 'falls back to a hardcoded recent version string' do
        ver = service.latest_version
        expect(ver).to match(/^\d+\.\d+\.\d+$/)
      end

      it 'does not raise' do
        expect { service.latest_version }.not_to raise_error
      end
    end
  end

  describe '#champion_id_map' do
    it 'returns a Hash mapping integer champion IDs to display names' do
      map = service.champion_id_map
      expect(map).to be_a(Hash)
      expect(map[222]).to eq('Jinx')
      expect(map[99]).to eq('Lux')
    end

    it 'does not include nil keys' do
      map = service.champion_id_map
      expect(map.keys).to all(be_a(Integer))
    end

    it 'does not include nil or empty-string values' do
      map = service.champion_id_map
      expect(map.values).to all(be_present)
    end

    context 'when CDN returns an HTTP error' do
      before do
        stub_request(:get, champion_url).to_return(status: 404)
      end

      it 'returns an empty hash (does not raise)' do
        expect(service.champion_id_map).to eq({})
      end
    end
  end

  describe '#champion_name_map' do
    it 'returns the inverted map: display name -> integer champion ID' do
      map = service.champion_name_map
      expect(map['Jinx']).to eq(222)
      expect(map['Lux']).to eq(99)
    end
  end

  describe '#all_champions' do
    it 'returns a Hash keyed by champion id string' do
      data = service.all_champions
      expect(data).to be_a(Hash)
      expect(data.keys).to include('Jinx', 'Lux', 'LeeSin')
    end

    it 'each value contains the champion key field' do
      data = service.all_champions
      expect(data['Jinx']['key']).to eq('222')
    end

    context 'when CDN returns an HTTP error' do
      before do
        stub_request(:get, champion_url).to_return(status: 503)
      end

      it 'returns an empty hash (does not raise)' do
        expect(service.all_champions).to eq({})
      end
    end
  end

  describe '#champion_by_key' do
    it 'returns a single champion hash for a valid key' do
      champion = service.champion_by_key('Jinx')
      expect(champion).to include('name' => 'Jinx')
    end

    it 'returns nil for an unknown key' do
      expect(service.champion_by_key('NonExistentChampion')).to be_nil
    end
  end

  describe 'champion name format (Riot Data Dragon invariant)' do
    it 'all stored champion IDs in champion_id_map are Riot Data Dragon names (id field from DDragon)' do
      # The values in champion_id_map come from the "name" field which can contain
      # spaces (e.g. "Lee Sin") or apostrophes. The keys of all_champions use the
      # "id" field (CamelCase, no spaces): "LeeSin", "KhaZix".
      all_data = service.all_champions
      all_data.each_key do |champion_key|
        # Champion id keys must be non-empty strings with no leading/trailing spaces
        expect(champion_key).to be_present
        expect(champion_key).to eq(champion_key.strip)
        # Must start with an uppercase letter (CamelCase DDragon convention)
        expect(champion_key[0]).to match(/[A-Z]/)
      end
    end

    it 'champion_id_map values are non-nil display names' do
      service.champion_id_map.each_value do |name|
        expect(name).to be_present
      end
    end
  end

  describe '#summoner_spells' do
    let(:spells_url) do
      "https://ddragon.leagueoflegends.com/cdn/#{version}/data/en_US/summoner.json"
    end

    before do
      stub_request(:get, spells_url)
        .to_return(status: 200,
                   body: { 'data' => { 'Flash' => { 'id' => 'Flash', 'key' => '4' } } }.to_json,
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns summoner spell data' do
      data = service.summoner_spells
      expect(data).to include('Flash')
    end

    context 'on CDN failure' do
      before do
        stub_request(:get, spells_url).to_return(status: 500)
      end

      it 'returns an empty hash without raising' do
        expect(service.summoner_spells).to eq({})
      end
    end
  end

  describe '#items' do
    let(:items_url) do
      "https://ddragon.leagueoflegends.com/cdn/#{version}/data/en_US/item.json"
    end

    before do
      stub_request(:get, items_url)
        .to_return(status: 200,
                   body: { 'data' => { '3031' => { 'name' => 'Infinity Edge' } } }.to_json,
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns items data keyed by item ID string' do
      data = service.items
      expect(data).to include('3031')
    end

    context 'on CDN failure' do
      before do
        stub_request(:get, items_url).to_return(status: 500)
      end

      it 'returns an empty hash without raising' do
        expect(service.items).to eq({})
      end
    end
  end

  describe '#profile_icons' do
    let(:icons_url) do
      "https://ddragon.leagueoflegends.com/cdn/#{version}/data/en_US/profileicon.json"
    end

    before do
      stub_request(:get, icons_url)
        .to_return(status: 200,
                   body: { 'data' => { '0' => { 'id' => 0 } } }.to_json,
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns profile icon data' do
      expect(service.profile_icons).to be_a(Hash)
    end

    context 'on CDN failure' do
      before do
        stub_request(:get, icons_url).to_return(status: 500)
      end

      it 'returns an empty hash without raising' do
        expect(service.profile_icons).to eq({})
      end
    end
  end

  describe '#clear_cache!' do
    it 'resets the memoized latest_version so it is re-fetched' do
      service.latest_version
      service.clear_cache!
      expect(service.instance_variable_get(:@latest_version)).to be_nil
    end

    it 'does not raise' do
      expect { service.clear_cache! }.not_to raise_error
    end
  end
end
