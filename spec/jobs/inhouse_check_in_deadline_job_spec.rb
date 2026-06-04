# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InhouseCheckInDeadlineJob, type: :job do
  let(:organization) { create(:organization) }
  let(:coach)        { create(:user, organization: organization) }

  before do
    allow(ActionCable.server).to receive(:broadcast)
  end

  describe '#perform' do
    context 'when the queue does not exist' do
      it 'returns without raising an error' do
        expect { described_class.new.perform(SecureRandom.uuid) }.not_to raise_error
      end
    end

    context 'when the queue is not in check_in status' do
      it 'does nothing when queue is open' do
        queue = create(:inhouse_queue, organization: organization, status: 'open',
                                       check_in_deadline: 1.minute.ago)

        expect { described_class.new.perform(queue.id) }.not_to raise_error
        expect(queue.reload.status).to eq('open')
      end

      it 'does nothing when queue is already closed' do
        queue = create(:inhouse_queue, organization: organization, status: 'closed',
                                       check_in_deadline: 1.minute.ago)

        expect { described_class.new.perform(queue.id) }.not_to raise_error
        expect(queue.reload.status).to eq('closed')
      end
    end

    context 'when the check-in deadline has not yet passed' do
      it 'does nothing and leaves the queue in check_in status' do
        queue = create(:inhouse_queue, organization: organization,
                                       status: 'check_in',
                                       check_in_deadline: 10.minutes.from_now)

        create(:inhouse_queue_entry, inhouse_queue: queue, checked_in: false)

        described_class.new.perform(queue.id)

        expect(queue.reload.status).to eq('check_in')
        expect(ActionCable.server).not_to have_received(:broadcast)
      end
    end

    context 'when deadline has passed with fewer than 2 checked-in players' do
      it 'closes the queue and broadcasts closed event' do
        queue = create(:inhouse_queue, organization: organization,
                                       status: 'check_in',
                                       check_in_deadline: 1.minute.ago)
        player = create(:player, organization: organization)
        create(:inhouse_queue_entry, inhouse_queue: queue, player: player, checked_in: false)

        described_class.new.perform(queue.id)

        expect(queue.reload.status).to eq('closed')
        expect(ActionCable.server).to have_received(:broadcast).with(
          "inhouse_queue_#{organization.id}",
          a_hash_including(event: 'check_in_expired', status: 'closed')
        )
      end

      it 'removes all unchecked entries from the queue' do
        queue = create(:inhouse_queue, organization: organization,
                                       status: 'check_in',
                                       check_in_deadline: 1.minute.ago)
        2.times { create(:inhouse_queue_entry, inhouse_queue: queue, checked_in: false) }

        described_class.new.perform(queue.id)

        expect(queue.inhouse_queue_entries.count).to eq(0)
      end
    end

    context 'when deadline has passed with 2 or more checked-in players' do
      it 'removes unchecked entries but keeps the queue in check_in status and broadcasts updated event' do
        queue = create(:inhouse_queue, organization: organization,
                                       status: 'check_in',
                                       check_in_deadline: 1.minute.ago)
        2.times do
          player = create(:player, organization: organization)
          create(:inhouse_queue_entry, inhouse_queue: queue, player: player, checked_in: true,
                                       checked_in_at: 5.minutes.ago)
        end
        player_unchecked = create(:player, organization: organization)
        unchecked = create(:inhouse_queue_entry, inhouse_queue: queue, player: player_unchecked, checked_in: false)

        described_class.new.perform(queue.id)

        expect(queue.reload.status).to eq('check_in')
        expect(InhouseQueueEntry.exists?(unchecked.id)).to be(false)
        expect(ActionCable.server).to have_received(:broadcast).with(
          "inhouse_queue_#{organization.id}",
          a_hash_including(event: 'check_in_expired', status: 'check_in')
        )
      end
    end

    context 'job metadata' do
      it 'is enqueued on the default queue' do
        expect(described_class.queue_name).to eq('default')
      end
    end
  end
end
