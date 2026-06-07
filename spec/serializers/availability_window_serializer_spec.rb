# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AvailabilityWindowSerializer do
  let(:organization) { create(:organization) }
  let(:window) { create(:availability_window, organization: organization) }

  subject(:result) { described_class.render_as_hash(window) }

  it 'exposes identifier' do
    expect(result[:id]).to eq(window.id)
  end

  it 'exposes core fields' do
    expect(result).to include(
      :day_of_week, :start_hour, :end_hour, :timezone,
      :game, :region, :tier_preference, :active,
      :created_at, :updated_at
    )
  end

  describe 'day_name field' do
    it 'is a string' do
      expect(result[:day_name]).to be_a(String)
    end
  end

  describe 'time_range field' do
    it 'is a string' do
      expect(result[:time_range]).to be_a(String)
    end
  end

  describe 'duration_hours field' do
    it 'is a numeric value' do
      expect(result[:duration_hours]).to be_a(Numeric)
    end

    it 'is positive' do
      expect(result[:duration_hours]).to be > 0
    end
  end

  describe 'expired field' do
    context 'when window has no expiry' do
      let(:window) { create(:availability_window, organization: organization, expires_at: nil) }

      it 'is false' do
        expect(result[:expired]).to be(false)
      end
    end

    context 'when window has expired' do
      let(:window) { create(:availability_window, :expired, organization: organization) }

      it 'is true' do
        expect(result[:expired]).to be(true)
      end
    end
  end

  describe 'active field' do
    context 'when window is active' do
      let(:window) { create(:availability_window, organization: organization, active: true) }

      it 'is true' do
        expect(result[:active]).to be(true)
      end
    end

    context 'when window is inactive' do
      let(:window) { create(:availability_window, :inactive, organization: organization) }

      it 'is false' do
        expect(result[:active]).to be(false)
      end
    end
  end
end
