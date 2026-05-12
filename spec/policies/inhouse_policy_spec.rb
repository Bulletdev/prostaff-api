# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InhousePolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:inhouse) { Inhouse.new(organization: organization, created_by: coach) }
  let(:record)  { inhouse }

  let(:owner)   { create(:user, :owner,   organization: organization) }
  let(:admin)   { create(:user, :admin,   organization: organization) }
  let(:coach)   { create(:user, :coach,   organization: organization) }
  let(:analyst) { create(:user, :analyst, organization: organization) }
  let(:viewer)  { create(:user, :viewer,  organization: organization) }

  let(:read_actions) do
    %i[index? active? ladder? sessions?]
  end

  let(:write_actions) do
    %i[create? balance_teams? start_draft? captain_pick? start_game? record_game? close? join?]
  end

  describe 'read actions (index, active, ladder, sessions)' do
    it 'grants access to any authenticated user' do
      [owner, admin, coach, analyst, viewer].each do |u|
        read_actions.each do |action|
          policy = described_class.new(u, record)
          expect(policy.public_send(action)).to be(true),
            "expected #{u.role} to be permitted for #{action}"
        end
      end
    end
  end

  describe 'write actions (create, balance_teams, start_draft, etc.)' do
    it 'grants access to coach, admin, and owner' do
      [coach, admin, owner].each do |u|
        write_actions.each do |action|
          policy = described_class.new(u, record)
          expect(policy.public_send(action)).to be(true),
            "expected #{u.role} to be permitted for #{action}"
        end
      end
    end

    it 'denies access to analyst and viewer' do
      [analyst, viewer].each do |u|
        write_actions.each do |action|
          policy = described_class.new(u, record)
          expect(policy.public_send(action)).to be(false),
            "expected #{u.role} to be denied for #{action}"
        end
      end
    end
  end
end
