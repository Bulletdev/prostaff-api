class Api::V1::Scouting::RegionsController < Api::V1::BaseController
  skip_before_action :authenticate_request!, only: [:index]

  def index
    regions = [
      { code: 'BR', name: 'Brazil', platform: 'BR1' },
      { code: 'NA', name: 'North America', platform: 'NA1' },
      { code: 'EUW', name: 'Europe West', platform: 'EUW1' },
      { code: 'EUNE', name: 'Europe Nordic & East', platform: 'EUN1' },
      { code: 'KR', name: 'Korea', platform: 'KR' },
      { code: 'JP', name: 'Japan', platform: 'JP1' },
      { code: 'OCE', name: 'Oceania', platform: 'OC1' },
      { code: 'LAN', name: 'Latin America North', platform: 'LA1' },
      { code: 'LAS', name: 'Latin America South', platform: 'LA2' },
      { code: 'RU', name: 'Russia', platform: 'RU' },
      { code: 'TR', name: 'Turkey', platform: 'TR1' }
    ]

    render_success({ regions: regions })
  end
end
