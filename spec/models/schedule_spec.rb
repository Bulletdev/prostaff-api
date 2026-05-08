# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Schedule, type: :model do
  let(:org) { create(:organization) }

  describe 'associations' do
    it { should belong_to(:organization) }
    it { should belong_to(:match).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:event_type) }
    it { should validate_presence_of(:start_time) }
    it { should validate_presence_of(:end_time) }

    it 'is invalid when end_time is before start_time' do
      sched = build(:schedule, organization: org,
                               start_time: 2.hours.from_now,
                               end_time: 1.hour.from_now)
      expect(sched).not_to be_valid
      expect(sched.errors[:end_time]).to be_present
    end

    it 'is invalid when end_time equals start_time' do
      t = 2.hours.from_now
      sched = build(:schedule, organization: org, start_time: t, end_time: t)
      expect(sched).not_to be_valid
    end
  end

  describe '#duration_minutes' do
    it 'returns the correct duration' do
      sched = build(:schedule, organization: org,
                               start_time: Time.current,
                               end_time: Time.current + 90.minutes)
      expect(sched.duration_minutes).to eq(90)
    end
  end

  describe '#is_upcoming?' do
    it 'returns true for a future schedule' do
      sched = build(:schedule, organization: org)
      expect(sched.is_upcoming?).to be true
    end

    it 'returns false for a past schedule' do
      sched = build(:schedule, :past, organization: org)
      expect(sched.is_upcoming?).to be false
    end
  end

  describe '#can_be_cancelled?' do
    it 'returns true when scheduled and upcoming' do
      sched = create(:schedule, organization: org)
      expect(sched.can_be_cancelled?).to be true
    end

    it 'returns false when already cancelled' do
      sched = create(:schedule, :cancelled, organization: org)
      expect(sched.can_be_cancelled?).to be false
    end
  end

  describe '#mark_as_completed!' do
    let(:sched) { create(:schedule, organization: org) }

    it 'sets status to completed' do
      sched.mark_as_completed!
      expect(sched.reload.status).to eq('completed')
    end
  end

  describe 'status normalization' do
    it 'normalizes in_progress to ongoing' do
      sched = build(:schedule, organization: org, status: 'in_progress')
      sched.valid?
      expect(sched.status).to eq('ongoing')
    end

    it 'normalizes done to completed' do
      sched = build(:schedule, organization: org, status: 'done')
      sched.valid?
      expect(sched.status).to eq('completed')
    end
  end

  describe 'scopes' do
    let!(:upcoming_sched) { create(:schedule, organization: org) }
    let!(:past_sched)     { create(:schedule, :past, organization: org) }
    # Use unscoped to bypass the OrganizationScoped default_scope (requires Current.organization_id)
    let(:schedules) { Schedule.unscoped.where(organization: org) }

    describe '.upcoming' do
      it 'returns future schedules' do
        expect(schedules.upcoming).to include(upcoming_sched)
        expect(schedules.upcoming).not_to include(past_sched)
      end
    end
  end
end
