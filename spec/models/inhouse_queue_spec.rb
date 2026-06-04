# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InhouseQueue, type: :model do
  let(:organization) { create(:organization) }
  let(:user)         { create(:user, organization: organization) }

  describe 'associations' do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to belong_to(:created_by).class_name('User') }
    it { is_expected.to have_many(:inhouse_queue_entries).dependent(:destroy) }
    it { is_expected.to have_many(:players).through(:inhouse_queue_entries) }
  end

  describe 'validations' do
    subject { build(:inhouse_queue, organization: organization, created_by: user) }

    it { is_expected.to validate_presence_of(:status) }

    it 'accepts valid status values' do
      %w[open check_in closed].each do |status|
        queue = build(:inhouse_queue, organization: organization, created_by: user, status: status)
        expect(queue).to be_valid, "expected status '#{status}' to be valid"
      end
    end

    it 'raises ArgumentError when assigned an invalid status value' do
      expect {
        build(:inhouse_queue, organization: organization, created_by: user, status: 'invalid')
      }.to raise_error(ArgumentError, /'invalid' is not a valid status/)
    end
  end

  describe 'enum' do
    it 'defines open status' do
      queue = create(:inhouse_queue, organization: organization, created_by: user, status: 'open')
      expect(queue.open?).to be(true)
    end

    it 'defines check_in status' do
      queue = create(:inhouse_queue, organization: organization, created_by: user, status: 'check_in')
      expect(queue.check_in?).to be(true)
    end

    it 'defines closed status' do
      queue = create(:inhouse_queue, :closed, organization: organization, created_by: user)
      expect(queue.closed?).to be(true)
    end
  end

  describe '#full?' do
    let(:queue) { create(:inhouse_queue, organization: organization, created_by: user) }

    it 'returns false when fewer than 10 entries exist' do
      expect(queue.full?).to be(false)
    end

    it 'returns true when 10 entries exist' do
      10.times do
        player = create(:player, organization: organization)
        create(:inhouse_queue_entry, inhouse_queue: queue, player: player)
      end

      expect(queue.full?).to be(true)
    end
  end

  describe '#slots_for_role' do
    let(:queue) { create(:inhouse_queue, organization: organization, created_by: user) }

    it 'returns 0 when no entries exist for a role' do
      expect(queue.slots_for_role('top')).to eq(0)
    end

    it 'counts entries for a specific role' do
      player1 = create(:player, organization: organization)
      player2 = create(:player, organization: organization)
      create(:inhouse_queue_entry, inhouse_queue: queue, player: player1, role: 'mid')
      create(:inhouse_queue_entry, inhouse_queue: queue, player: player2, role: 'mid')

      expect(queue.slots_for_role('mid')).to eq(2)
      expect(queue.slots_for_role('top')).to eq(0)
    end
  end

  describe '#checked_in_entries' do
    let(:queue) { create(:inhouse_queue, organization: organization, created_by: user) }

    it 'returns only checked-in entries' do
      player1 = create(:player, organization: organization)
      player2 = create(:player, organization: organization)
      checked_entry  = create(:inhouse_queue_entry, :checked_in, inhouse_queue: queue, player: player1)
      pending_entry  = create(:inhouse_queue_entry, inhouse_queue: queue, player: player2)

      result = queue.checked_in_entries
      expect(result).to include(checked_entry)
      expect(result).not_to include(pending_entry)
    end
  end

  describe 'scopes' do
    let!(:open_queue)     { create(:inhouse_queue, organization: organization, created_by: user, status: 'open') }
    let!(:checkin_queue)  { create(:inhouse_queue, organization: organization, created_by: user, status: 'check_in') }
    let!(:closed_queue)   { create(:inhouse_queue, :closed, organization: organization, created_by: user) }

    describe '.active' do
      it 'includes open and check_in queues' do
        active = InhouseQueue.active
        expect(active).to include(open_queue, checkin_queue)
        expect(active).not_to include(closed_queue)
      end
    end
  end

  describe '#serialize' do
    let(:queue) { create(:inhouse_queue, organization: organization, created_by: user) }

    it 'returns a hash with expected keys' do
      result = queue.serialize
      expect(result).to include(:id, :status, :total_entries, :total_slots, :full)
    end

    it 'includes entries_by_role when detailed: true' do
      result = queue.serialize(detailed: true)
      expect(result).to have_key(:entries_by_role)
      InhouseQueue::ROLES.each do |role|
        expect(result[:entries_by_role]).to have_key(role)
      end
    end
  end
end

RSpec.describe InhouseQueueEntry, type: :model do
  let(:organization) { create(:organization) }
  let(:user)         { create(:user, organization: organization) }
  let(:queue)        { create(:inhouse_queue, organization: organization, created_by: user) }

  describe 'associations' do
    it { is_expected.to belong_to(:inhouse_queue) }
    it { is_expected.to belong_to(:player) }
  end

  describe 'validations' do
    it 'accepts valid LoL roles' do
      %w[top jungle mid adc support].each do |role|
        player = create(:player, organization: organization)
        entry  = build(:inhouse_queue_entry, inhouse_queue: queue, player: player, role: role)
        expect(entry).to be_valid, "expected role '#{role}' to be valid"
      end
    end

    it 'rejects invalid roles' do
      player = create(:player, organization: organization)
      entry  = build(:inhouse_queue_entry, inhouse_queue: queue, player: player, role: 'carry')
      expect(entry).not_to be_valid
      expect(entry.errors[:role]).to be_present
    end

    it 'enforces one player per queue' do
      player = create(:player, organization: organization)
      create(:inhouse_queue_entry, inhouse_queue: queue, player: player, role: 'top')
      duplicate = build(:inhouse_queue_entry, inhouse_queue: queue, player: player, role: 'mid')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:player_id]).to be_present
    end
  end

  describe '#serialize' do
    it 'returns a hash with expected keys' do
      player = create(:player, organization: organization)
      entry  = create(:inhouse_queue_entry, inhouse_queue: queue, player: player, role: 'adc')
      result = entry.serialize
      expect(result).to include(:id, :player_id, :role, :checked_in)
      expect(result[:role]).to eq('adc')
    end
  end
end
