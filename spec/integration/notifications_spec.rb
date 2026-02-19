# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Notifications API', type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :admin, organization: organization) }
  let(:Authorization) { "Bearer #{Authentication::Services::JwtService.encode(user_id: user.id)}" }

  # ---------------------------------------------------------------------------
  # Notifications
  # ---------------------------------------------------------------------------

  path '/api/v1/notifications' do
    get 'List notifications for the current user' do
      tags 'Notifications'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false
      parameter name: :status, in: :query, type: :string, required: false,
                description: 'Filter by status: read, unread'

      response '200', 'notifications returned' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     notifications: {
                       type: :array,
                       items: {
                         type: :object,
                         properties: {
                           id: { type: :string },
                           title: { type: :string },
                           body: { type: :string },
                           notification_type: { type: :string },
                           read: { type: :boolean },
                           read_at: { type: :string, format: 'date-time', nullable: true },
                           created_at: { type: :string, format: 'date-time' }
                         }
                       }
                     },
                     pagination: { '$ref' => '#/components/schemas/Pagination' }
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

  path '/api/v1/notifications/unread_count' do
    get 'Get the count of unread notifications' do
      tags 'Notifications'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'unread count returned' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     unread_count: { type: :integer }
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

  path '/api/v1/notifications/mark_all_as_read' do
    patch 'Mark all notifications as read' do
      tags 'Notifications'
      produces 'application/json'
      security [bearerAuth: []]

      response '200', 'all notifications marked as read' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     updated_count: { type: :integer }
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

  path '/api/v1/notifications/{id}' do
    get 'Get a specific notification' do
      tags 'Notifications'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'notification found' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:id) { 'nonexistent' }
        run_test!
      end

      response '404', 'notification not found' do
        schema '$ref' => '#/components/schemas/Error'
        let(:id) { 'nonexistent' }
        run_test!
      end
    end

    delete 'Delete a notification' do
      tags 'Notifications'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'notification deleted' do
        schema type: :object,
               properties: { message: { type: :string } }
        let(:id) { 'nonexistent' }
        run_test!
      end

      response '404', 'notification not found' do
        schema '$ref' => '#/components/schemas/Error'
        let(:id) { 'nonexistent' }
        run_test!
      end
    end
  end

  path '/api/v1/notifications/{id}/mark_as_read' do
    patch 'Mark a notification as read' do
      tags 'Notifications'
      produces 'application/json'
      security [bearerAuth: []]

      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'notification marked as read' do
        schema type: :object,
               properties: { data: { type: :object } }
        let(:id) { 'nonexistent' }
        run_test!
      end

      response '404', 'notification not found' do
        schema '$ref' => '#/components/schemas/Error'
        let(:id) { 'nonexistent' }
        run_test!
      end
    end
  end
end
