# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VodReviewSerializer do
  let(:organization) { create(:organization) }
  let(:reviewer) { create(:user, :coach, organization: organization) }
  let(:match) { create(:match, organization: organization) }
  let(:vod_review) do
    create(:vod_review,
           organization: organization,
           reviewer: reviewer,
           match: match)
  end

  subject(:result) { described_class.render_as_hash(vod_review) }

  it 'exposes identifier' do
    expect(result[:id]).to eq(vod_review.id)
  end

  it 'exposes core fields' do
    expect(result).to include(
      :title, :description, :review_type, :review_date,
      :video_url, :status, :is_public,
      :created_at, :updated_at
    )
  end

  describe 'hashid field' do
    it 'is present and a string' do
      expect(result[:hashid]).to be_a(String)
      expect(result[:hashid]).not_to be_empty
    end
  end

  describe 'public_url field' do
    it 'is present' do
      expect(result).to have_key(:public_url)
    end
  end

  describe 'public_hashid_url field' do
    it 'is present' do
      expect(result).to have_key(:public_hashid_url)
    end
  end

  describe 'timestamps_count field' do
    context 'without include_timestamps_count option' do
      it 'is nil' do
        expect(result[:timestamps_count]).to be_nil
      end
    end

    context 'with include_timestamps_count: true' do
      subject(:result) do
        described_class.render_as_hash(vod_review, include_timestamps_count: true)
      end

      it 'is an integer' do
        expect(result[:timestamps_count]).to be_a(Integer)
        expect(result[:timestamps_count]).to be >= 0
      end
    end
  end

  describe 'status field' do
    it 'is a known lifecycle value' do
      expect(result[:status]).to be_in(%w[draft published archived])
    end

    context 'when published' do
      let(:vod_review) do
        create(:vod_review, :published, organization: organization,
                                        reviewer: reviewer, match: match)
      end

      it 'is published' do
        expect(result[:status]).to eq('published')
      end
    end
  end

  describe 'organization association' do
    it 'includes organization id' do
      expect(result[:organization][:id]).to eq(organization.id)
    end
  end

  describe 'reviewer association' do
    it 'includes reviewer id' do
      expect(result[:reviewer][:id]).to eq(reviewer.id)
    end

    it 'does not expose password_digest' do
      expect(result[:reviewer].keys).not_to include(:password_digest)
    end
  end

  describe 'match association' do
    it 'includes match id' do
      expect(result[:match][:id]).to eq(match.id)
    end
  end

  describe 'multi-pov fields' do
    it 'exposes video_urls as an array' do
      expect(result).to have_key(:video_urls)
      expect(result[:video_urls]).to be_an(Array)
    end

    it 'exposes video_sync_offsets as an array' do
      expect(result).to have_key(:video_sync_offsets)
      expect(result[:video_sync_offsets]).to be_an(Array)
    end

    it 'exposes video_labels as an array' do
      expect(result).to have_key(:video_labels)
      expect(result[:video_labels]).to be_an(Array)
    end

    context 'when review has multi-pov data' do
      let(:vod_review) do
        create(:vod_review,
               organization: organization,
               reviewer: reviewer,
               match: match,
               review_type: 'multi_pov',
               video_urls: ['https://www.youtube.com/watch?v=pov1', 'https://www.youtube.com/watch?v=pov2'],
               video_sync_offsets: [0, 5],
               video_labels: ['Player A', 'Player B'])
      end

      it 'serializes video_urls correctly' do
        expect(result[:video_urls]).to eq(['https://www.youtube.com/watch?v=pov1',
                                           'https://www.youtube.com/watch?v=pov2'])
      end

      it 'serializes video_sync_offsets correctly' do
        expect(result[:video_sync_offsets]).to eq([0, 5])
      end

      it 'serializes video_labels correctly' do
        expect(result[:video_labels]).to eq(['Player A', 'Player B'])
      end
    end
  end
end
