# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FeedbackPolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:record)       { Feedback }

  let(:owner)   { create(:user, :owner,   organization: organization) }
  let(:admin)   { create(:user, :admin,   organization: organization) }
  let(:coach)   { create(:user, :coach,   organization: organization) }
  let(:analyst) { create(:user, :analyst, organization: organization) }
  let(:viewer)  { create(:user, :viewer,  organization: organization) }

  describe 'index?' do
    it 'permits any authenticated user' do
      [owner, admin, coach, analyst, viewer].each do |u|
        policy = described_class.new(u, record)
        expect(policy.index?).to be(true),
          "expected #{u.role} to be permitted for index?"
      end
    end

    it 'denies nil user (unauthenticated)' do
      policy = described_class.new(nil, record)
      expect(policy.index?).to be(false)
    end
  end

  describe 'create?' do
    it 'permits any authenticated user' do
      [owner, admin, coach, analyst, viewer].each do |u|
        policy = described_class.new(u, record)
        expect(policy.create?).to be(true),
          "expected #{u.role} to be permitted for create?"
      end
    end

    it 'denies nil user (unauthenticated)' do
      policy = described_class.new(nil, record)
      expect(policy.create?).to be(false)
    end
  end
end
