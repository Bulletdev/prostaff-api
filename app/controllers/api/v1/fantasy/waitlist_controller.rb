# frozen_string_literal: true

module Api
  module V1
    module Fantasy
      class WaitlistController < ApplicationController
        # POST /api/v1/fantasy/waitlist
        def create
          email = params[:email]&.strip&.downcase

          if email.blank?
            render json: {
              error: {
                code: 'VALIDATION_ERROR',
                message: 'Email is required'
              }
            }, status: :unprocessable_entity
            return
          end

          # Check if email already exists
          existing = FantasyWaitlist.find_by(email: email)
          if existing
            render json: {
              message: 'You are already on the waitlist!',
              data: { email: existing.email, subscribed_at: existing.subscribed_at }
            }, status: :ok
            return
          end

          # Create new waitlist entry
          waitlist = FantasyWaitlist.new(email: email)

          if waitlist.save
            render json: {
              message: 'Successfully joined the waitlist!',
              data: {
                email: waitlist.email,
                subscribed_at: waitlist.subscribed_at
              }
            }, status: :created
          else
            render json: {
              error: {
                code: 'VALIDATION_ERROR',
                message: waitlist.errors.full_messages.join(', ')
              }
            }, status: :unprocessable_entity
          end
        rescue StandardError => e
          Rails.logger.error("Fantasy Waitlist Error: #{e.message}")
          render json: {
            error: {
              code: 'SERVER_ERROR',
              message: 'Failed to join waitlist. Please try again.'
            }
          }, status: :internal_server_error
        end

        # GET /api/v1/fantasy/waitlist/stats (Public stats)
        def stats
          total = FantasyWaitlist.count
          recent = FantasyWaitlist.where('created_at > ?', 7.days.ago).count

          render json: {
            data: {
              total: total,
              last_7_days: recent
            }
          }
        end
      end
    end
  end
end
