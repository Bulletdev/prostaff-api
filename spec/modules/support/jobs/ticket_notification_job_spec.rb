# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Support::TicketNotificationJob, type: :job do
  include ActiveJob::TestHelper

  let(:organization) { create(:organization) }
  let(:user)         { create(:user, organization: organization) }
  let(:ticket) do
    create(:support_ticket,
           user: user,
           organization: organization,
           subject: 'Test ticket subject here',
           description: 'This is a detailed description of the issue.',
           category: 'technical',
           priority: 'medium',
           status: 'open')
  end

  describe '#perform' do
    # ── Queue configuration ─────────────────────────────────────────────────

    it 'is enqueued on the default queue' do
      expect(described_class.queue_name).to eq('default')
    end

    # ── notification_type: created ──────────────────────────────────────────

    context "when notification_type is 'created'" do
      it 'creates an in_app notification for the ticket user' do
        expect do
          described_class.new.perform(ticket.id, 'created')
        end.to change(Notification, :count).by(1)
      end

      it 'sets the notification title to Ticket Criado' do
        described_class.new.perform(ticket.id, 'created')
        notification = Notification.last
        expect(notification.title).to eq('Ticket Criado')
      end

      it 'associates the notification with the correct user' do
        described_class.new.perform(ticket.id, 'created')
        notification = Notification.last
        expect(notification.user_id).to eq(user.id)
      end

      it 'includes the ticket subject in the notification message' do
        described_class.new.perform(ticket.id, 'created')
        notification = Notification.last
        expect(notification.message).to include(ticket.subject)
      end

      it 'does not raise for valid ticket' do
        expect { described_class.new.perform(ticket.id, 'created') }.not_to raise_error
      end
    end

    # ── notification_type: status_changed ──────────────────────────────────

    context "when notification_type is 'status_changed'" do
      before { ticket.update!(status: 'in_progress') }

      it 'creates an in_app notification' do
        expect do
          described_class.new.perform(ticket.id, 'status_changed')
        end.to change(Notification, :count).by(1)
      end

      it 'sets title to Status do Ticket Alterado' do
        described_class.new.perform(ticket.id, 'status_changed')
        expect(Notification.last.title).to eq('Status do Ticket Alterado')
      end

      it 'includes the current status in the message' do
        described_class.new.perform(ticket.id, 'status_changed')
        expect(Notification.last.message).to include(ticket.status)
      end
    end

    # ── notification_type: resolved ────────────────────────────────────────

    context "when notification_type is 'resolved'" do
      it 'creates an in_app notification with success type' do
        expect do
          described_class.new.perform(ticket.id, 'resolved')
        end.to change(Notification, :count).by(1)
      end

      it 'sets notification title to Ticket Resolvido' do
        described_class.new.perform(ticket.id, 'resolved')
        expect(Notification.last.title).to eq('Ticket Resolvido')
      end

      it 'creates notification of type success' do
        described_class.new.perform(ticket.id, 'resolved')
        expect(Notification.last.type).to eq('success')
      end
    end

    # ── notification_type: new_message ─────────────────────────────────────

    context "when notification_type is 'new_message'" do
      let(:staff_user) { create(:user, :admin, organization: organization) }
      let(:message) do
        create(:support_ticket_message,
               support_ticket: ticket,
               user: staff_user,
               content: 'Staff reply here',
               message_type: 'staff') rescue nil
      end

      before do
        # Build message manually to avoid after_create callback triggering another job
        @message = SupportTicketMessage.new(
          support_ticket: ticket,
          user: staff_user,
          content: 'Staff reply here',
          message_type: 'staff'
        )
        @message.save!(validate: true)
        # Clear jobs queued by after_create
        clear_enqueued_jobs
      end

      it 'creates a notification referencing the new message' do
        expect do
          described_class.new.perform(ticket.id, 'new_message', @message.id)
        end.to change(Notification, :count).by(1)
      end

      it 'sets the title to Nova Mensagem no Ticket' do
        described_class.new.perform(ticket.id, 'new_message', @message.id)
        expect(Notification.last.title).to eq('Nova Mensagem no Ticket')
      end
    end

    # ── Error path: ticket not found ───────────────────────────────────────

    context 'when ticket_id does not exist' do
      it 'logs an error and does not raise' do
        expect(Rails.logger).to receive(:error).with(/not found/)
        expect do
          described_class.new.perform('00000000-0000-0000-0000-000000000000', 'created')
        end.not_to raise_error
      end

      it 'does not create a notification' do
        allow(Rails.logger).to receive(:error)
        expect do
          described_class.new.perform('00000000-0000-0000-0000-000000000000', 'created')
        end.not_to change(Notification, :count)
      end
    end

    # ── Unknown notification_type: no-op ───────────────────────────────────

    context 'when notification_type is unknown' do
      it 'does not raise' do
        expect { described_class.new.perform(ticket.id, 'unknown_type') }.not_to raise_error
      end

      it 'does not create any notification' do
        expect do
          described_class.new.perform(ticket.id, 'unknown_type')
        end.not_to change(Notification, :count)
      end
    end

    # ── Enqueue via perform_later ──────────────────────────────────────────

    it 'can be enqueued via perform_later' do
      expect do
        described_class.perform_later(ticket.id, 'created')
      end.to have_enqueued_job(described_class).with(ticket.id, 'created').on_queue('default')
    end
  end
end
