# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Inhouse, type: :model do
  let(:organization) { create(:organization) }
  let(:coach_user)   { create(:user, :coach, organization: organization) }

  def build_inhouse(**attrs)
    Inhouse.new({
      organization: organization,
      created_by: coach_user,
      status: 'waiting'
    }.merge(attrs))
  end

  def create_inhouse(**attrs)
    build_inhouse(**attrs).tap(&:save!)
  end

  describe 'validations' do
    it 'is valid with status waiting' do
      expect(build_inhouse).to be_valid
    end

    it 'rejects invalid status values' do
      expect { build_inhouse(status: 'invalid') }.to raise_error(ArgumentError)
    end

    it 'rejects invalid status transitions on update' do
      inhouse = create_inhouse(status: 'waiting')
      inhouse.update!(status: 'done')
      inhouse.status = 'waiting'
      expect(inhouse).not_to be_valid
      expect(inhouse.errors[:status]).to be_present
    end

    it 'allows valid transition from waiting to draft' do
      inhouse = create_inhouse(status: 'waiting')
      inhouse.status = 'draft'
      expect(inhouse).to be_valid
    end

    it 'allows valid transition from waiting to in_progress' do
      inhouse = create_inhouse(status: 'waiting')
      inhouse.status = 'in_progress'
      expect(inhouse).to be_valid
    end

    it 'prevents illegal transition from in_progress to draft' do
      inhouse = create_inhouse(status: 'waiting')
      inhouse.update!(status: 'draft')
      inhouse.update!(status: 'in_progress')
      inhouse.status = 'draft'
      expect(inhouse).not_to be_valid
    end
  end

  describe 'scopes' do
    it '.active includes waiting, draft, and in_progress statuses' do
      waiting    = create_inhouse(status: 'waiting')
      done_house = create_inhouse(status: 'waiting')
      done_house.update!(status: 'done')

      expect(Inhouse.active).to include(waiting)
      expect(Inhouse.active).not_to include(done_house)
    end

    it '.history includes only done inhousess' do
      waiting    = create_inhouse(status: 'waiting')
      done_house = create_inhouse(status: 'waiting')
      done_house.update!(status: 'done')

      expect(Inhouse.history).to include(done_house)
      expect(Inhouse.history).not_to include(waiting)
    end
  end

  describe '#current_pick_team' do
    it 'returns nil when status is not draft' do
      expect(build_inhouse(status: 'waiting').current_pick_team).to be_nil
    end

    it 'returns the correct team for pick number 0 (blue first)' do
      inhouse = create_inhouse(status: 'waiting')
      inhouse.update_columns(status: 'draft', draft_pick_number: 0)
      expect(inhouse.current_pick_team).to eq(Inhouse::PICK_ORDER[0])
    end

    it 'returns nil when all picks are exhausted' do
      inhouse = create_inhouse(status: 'waiting')
      inhouse.update_columns(status: 'draft', draft_pick_number: Inhouse::PICK_ORDER.size)
      expect(inhouse.current_pick_team).to be_nil
    end
  end

  describe '#draft_complete?' do
    it 'returns true when pick number equals PICK_ORDER size' do
      inhouse = build_inhouse(draft_pick_number: Inhouse::PICK_ORDER.size)
      expect(inhouse.draft_complete?).to be(true)
    end

    it 'returns false when picks remain' do
      inhouse = build_inhouse(draft_pick_number: 3)
      expect(inhouse.draft_complete?).to be(false)
    end

    it 'returns false when draft_pick_number is nil' do
      inhouse = build_inhouse(draft_pick_number: nil)
      expect(inhouse.draft_complete?).to be(false)
    end
  end
end
