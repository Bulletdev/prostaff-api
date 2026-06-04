# frozen_string_literal: true

RSpec.shared_context 'riot api stubs' do
  before do
    stub_request(:get, %r{\.api\.riotgames\.com/}).to_return(
      status: 200,
      body: { id: 'summoner-id', puuid: 'puuid-123', summonerLevel: 100 }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
  end
end
