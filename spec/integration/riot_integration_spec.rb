# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Riot Integration API', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, organization: organization) }
  let(:Authorization) { "Bearer #{Authentication::Services::JwtService.encode(user_id: user.id)}" }

  path '/api/v1/riot-integration/sync-status' do
    get 'Get Riot API synchronization status' do
      tags 'Riot Integration'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Returns statistics about player data synchronization with Riot API'

      response '200', 'sync status retrieved' do
        before do
          create(:player, organization: organization, sync_status: 'success', last_sync_at: 1.hour.ago)
          create(:player, organization: organization, sync_status: 'pending', last_sync_at: nil)
          create(:player, organization: organization, sync_status: 'error', last_sync_at: 2.hours.ago)
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     stats: {
                       type: :object,
                       properties: {
                         total_players: { type: :integer, description: 'Total number of players in the organization' },
                         synced_players: { type: :integer, description: 'Players successfully synced' },
                         pending_sync: { type: :integer, description: 'Players pending synchronization' },
                         failed_sync: { type: :integer, description: 'Players with failed sync' },
                         recently_synced: { type: :integer, description: 'Players synced in the last 24 hours' },
                         needs_sync: { type: :integer, description: 'Players that need to be synced' }
                       }
                     },
                     recent_syncs: {
                       type: :array,
                       description: 'List of 10 most recently synced players',
                       items: {
                         type: :object,
                         properties: {
                           id: { type: :string },
                           summoner_name: { type: :string },
                           last_sync_at: { type: :string, format: 'date-time' },
                           sync_status: { type: :string, enum: %w[pending success error] }
                         }
                       }
                     }
                   }
                 }
               }

        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end
end
