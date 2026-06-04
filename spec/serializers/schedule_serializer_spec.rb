# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScheduleSerializer do
  let(:organization) { create(:organization) }
  let(:schedule) { create(:schedule, organization: organization) }

  subject(:result) { described_class.render_as_hash(schedule) }

  it 'exposes identifier' do
    expect(result[:id]).to eq(schedule.id)
  end

  it 'exposes core fields' do
    expect(result).to include(
      :event_type, :title, :start_time, :end_time,
      :status, :created_at, :updated_at
    )
  end

  describe 'duration_hours field' do
    it 'is a numeric value when start and end times are set' do
      expect(result[:duration_hours]).to be_a(Numeric)
    end

    it 'is positive' do
      expect(result[:duration_hours]).to be > 0
    end

    context 'when event spans exactly 2 hours' do
      let(:fixed_start) { 2.days.from_now.change(sec: 0) }
      let(:schedule) do
        create(:schedule, organization: organization,
                          start_time: fixed_start,
                          end_time: fixed_start + 2.hours)
      end

      it 'returns 2.0' do
        expect(result[:duration_hours]).to eq(2.0)
      end
    end
  end

  describe 'organization association' do
    it 'includes organization id' do
      expect(result[:organization][:id]).to eq(organization.id)
    end
  end

  describe 'match association' do
    context 'when no match is linked' do
      it 'is nil' do
        expect(result[:match]).to be_nil
      end
    end

    context 'when a match is linked' do
      let(:match) { create(:match, organization: organization) }
      let(:schedule) { create(:schedule, organization: organization, match: match) }

      it 'includes the match id' do
        expect(result[:match][:id]).to eq(match.id)
      end
    end
  end

  describe 'status field' do
    it 'is a string' do
      expect(result[:status]).to be_a(String)
    end

    context 'when cancelled' do
      let(:schedule) { create(:schedule, :cancelled, organization: organization) }

      it 'is cancelled' do
        expect(result[:status]).to eq('cancelled')
      end
    end
  end
end
