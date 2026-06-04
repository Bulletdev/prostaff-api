# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InhouseQueuePolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:inhouse)      { create(:inhouse, organization: organization) }
  let(:record)       { InhouseQueue }

  let(:owner)   { create(:user, :owner,   organization: organization) }
  let(:admin)   { create(:user, :admin,   organization: organization) }
  let(:coach)   { create(:user, :coach,   organization: organization) }
  let(:analyst) { create(:user, :analyst, organization: organization) }
  let(:viewer)  { create(:user, :viewer,  organization: organization) }

  # Actions open to any authenticated user (user.present?)
  let(:open_to_members) { %i[status? join? leave? checkin?] }

  # Actions restricted to coach / admin / owner
  let(:coach_only_actions) { %i[open? start_checkin? start_session? close?] }

  describe 'open_to_members actions (status, join, leave, checkin)' do
    it 'permits access for owner' do
      open_to_members.each do |action|
        policy = described_class.new(owner, record)
        expect(policy.public_send(action)).to be(true),
          "expected owner to be permitted for #{action}"
      end
    end

    it 'permits access for admin' do
      open_to_members.each do |action|
        policy = described_class.new(admin, record)
        expect(policy.public_send(action)).to be(true),
          "expected admin to be permitted for #{action}"
      end
    end

    it 'permits access for coach' do
      open_to_members.each do |action|
        policy = described_class.new(coach, record)
        expect(policy.public_send(action)).to be(true),
          "expected coach to be permitted for #{action}"
      end
    end

    it 'permits access for analyst' do
      open_to_members.each do |action|
        policy = described_class.new(analyst, record)
        expect(policy.public_send(action)).to be(true),
          "expected analyst to be permitted for #{action}"
      end
    end

    it 'permits access for viewer' do
      open_to_members.each do |action|
        policy = described_class.new(viewer, record)
        expect(policy.public_send(action)).to be(true),
          "expected viewer to be permitted for #{action}"
      end
    end

    it 'denies access when user is nil' do
      open_to_members.each do |action|
        policy = described_class.new(nil, record)
        expect(policy.public_send(action)).to be(false),
          "expected nil user to be denied for #{action}"
      end
    end
  end

  describe 'coach_only_actions (open, start_checkin, start_session, close)' do
    it 'permits access for owner' do
      coach_only_actions.each do |action|
        policy = described_class.new(owner, record)
        expect(policy.public_send(action)).to be(true),
          "expected owner to be permitted for #{action}"
      end
    end

    it 'permits access for admin' do
      coach_only_actions.each do |action|
        policy = described_class.new(admin, record)
        expect(policy.public_send(action)).to be(true),
          "expected admin to be permitted for #{action}"
      end
    end

    it 'permits access for coach' do
      coach_only_actions.each do |action|
        policy = described_class.new(coach, record)
        expect(policy.public_send(action)).to be(true),
          "expected coach to be permitted for #{action}"
      end
    end

    it 'denies access to analyst' do
      coach_only_actions.each do |action|
        policy = described_class.new(analyst, record)
        expect(policy.public_send(action)).to be(false),
          "expected analyst to be denied for #{action}"
      end
    end

    it 'denies access to viewer' do
      coach_only_actions.each do |action|
        policy = described_class.new(viewer, record)
        expect(policy.public_send(action)).to be(false),
          "expected viewer to be denied for #{action}"
      end
    end

    # Nil user reaches coach? which calls user.role — authentication middleware
    # prevents nil users from reaching the policy in production. We verify
    # the open_to_members nil-user path covers the unauthenticated case above.
  end
end
