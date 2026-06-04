# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScrimRequestSerializer do
  let(:org_a) { create(:organization) }
  let(:org_b) { create(:organization) }
  let(:scrim_request) do
    create(:scrim_request,
           requesting_organization: org_a,
           target_organization: org_b)
  end

  subject(:result) { described_class.render_as_hash(scrim_request) }

  it 'exposes identifier' do
    expect(result[:id]).to eq(scrim_request.id)
  end

  it 'exposes core fields' do
    expect(result).to include(
      :status, :game, :message, :proposed_at, :expires_at,
      :games_planned, :created_at, :updated_at
    )
  end

  describe 'requesting_organization field' do
    it 'is a hash with org id and name' do
      expect(result[:requesting_organization]).to include(
        id: org_a.id,
        name: org_a.name
      )
    end

    it 'includes avg_tier' do
      expect(result[:requesting_organization]).to have_key(:avg_tier)
    end

    it 'includes roster as an array' do
      expect(result[:requesting_organization][:roster]).to be_an(Array)
    end
  end

  describe 'target_organization field' do
    it 'is a hash with org id and name' do
      expect(result[:target_organization]).to include(
        id: org_b.id,
        name: org_b.name
      )
    end
  end

  describe 'pending field' do
    context 'when status is pending' do
      let(:scrim_request) do
        create(:scrim_request, :pending,
               requesting_organization: org_a, target_organization: org_b)
      end

      it 'is true' do
        expect(result[:pending]).to be(true)
      end
    end

    context 'when status is accepted' do
      let(:scrim_request) do
        create(:scrim_request, :accepted,
               requesting_organization: org_a, target_organization: org_b)
      end

      it 'is false' do
        expect(result[:pending]).to be(false)
      end
    end
  end

  describe 'expired field' do
    context 'when not expired' do
      it 'is false' do
        expect(result[:expired]).to be(false)
      end
    end

    context 'when expired' do
      let(:scrim_request) do
        create(:scrim_request, :expired,
               requesting_organization: org_a, target_organization: org_b)
      end

      it 'is true' do
        expect(result[:expired]).to be(true)
      end
    end
  end
end
