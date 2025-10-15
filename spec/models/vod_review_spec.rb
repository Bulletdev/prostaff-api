require 'rails_helper'

RSpec.describe VodReview, type: :model do
  describe 'associations' do
    it { should belong_to(:organization) }
    it { should belong_to(:match).optional }
    it { should belong_to(:reviewer).class_name('User').optional }
    it { should have_many(:vod_timestamps).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_length_of(:title).is_at_most(255) }
    it { should validate_presence_of(:video_url) }
    it { should validate_inclusion_of(:review_type).in_array(%w[team individual opponent]).allow_blank }
    it { should validate_inclusion_of(:status).in_array(%w[draft published archived]) }

    describe 'video_url format' do
      it 'accepts valid URLs' do
        vod_review = build(:vod_review, video_url: 'https://www.youtube.com/watch?v=abc123')
        expect(vod_review).to be_valid
      end

      it 'rejects invalid URLs' do
        vod_review = build(:vod_review, video_url: 'not-a-valid-url')
        expect(vod_review).not_to be_valid
      end
    end

    describe 'share_link uniqueness' do
      let!(:existing_vod_review) { create(:vod_review, :public) }

      it 'validates uniqueness of share_link' do
        new_vod_review = build(:vod_review, share_link: existing_vod_review.share_link)
        expect(new_vod_review).not_to be_valid
      end
    end
  end

  describe 'callbacks' do
    describe 'generate_share_link' do
      it 'generates share_link for public vod reviews on create' do
        vod_review = create(:vod_review, is_public: true)
        expect(vod_review.share_link).to be_present
      end

      it 'does not generate share_link for private vod reviews' do
        vod_review = create(:vod_review, is_public: false, share_link: nil)
        expect(vod_review.share_link).to be_nil
      end
    end
  end

  describe 'scopes' do
    let(:organization) { create(:organization) }
    let!(:draft_review) { create(:vod_review, status: 'draft', organization: organization) }
    let!(:published_review) { create(:vod_review, :published, organization: organization) }
    let!(:archived_review) { create(:vod_review, :archived, organization: organization) }
    let!(:public_review) { create(:vod_review, :public, organization: organization) }

    describe '.by_status' do
      it 'filters by status' do
        expect(VodReview.by_status('draft')).to include(draft_review)
        expect(VodReview.by_status('draft')).not_to include(published_review)
      end
    end

    describe '.published' do
      it 'returns only published reviews' do
        expect(VodReview.published).to include(published_review)
        expect(VodReview.published).not_to include(draft_review)
      end
    end

    describe '.public_reviews' do
      it 'returns only public reviews' do
        expect(VodReview.public_reviews).to include(public_review)
        expect(VodReview.public_reviews).not_to include(draft_review)
      end
    end

    describe '.by_type' do
      let!(:team_review) { create(:vod_review, review_type: 'team', organization: organization) }

      it 'filters by review type' do
        expect(VodReview.by_type('team')).to include(team_review)
      end
    end
  end

  describe 'instance methods' do
    let(:vod_review) { create(:vod_review, duration: 3665) }

    describe '#duration_formatted' do
      it 'formats duration with hours' do
        expect(vod_review.duration_formatted).to eq('1:01:05')
      end

      it 'formats duration without hours' do
        vod_review.update(duration: 125)
        expect(vod_review.duration_formatted).to eq('2:05')
      end

      it 'returns Unknown for blank duration' do
        vod_review.update(duration: nil)
        expect(vod_review.duration_formatted).to eq('Unknown')
      end
    end

    describe '#status_color' do
      it 'returns yellow for draft' do
        vod_review.update(status: 'draft')
        expect(vod_review.status_color).to eq('yellow')
      end

      it 'returns green for published' do
        vod_review.update(status: 'published')
        expect(vod_review.status_color).to eq('green')
      end

      it 'returns gray for archived' do
        vod_review.update(status: 'archived')
        expect(vod_review.status_color).to eq('gray')
      end
    end

    describe '#publish!' do
      it 'publishes the review' do
        vod_review.publish!
        expect(vod_review.status).to eq('published')
        expect(vod_review.share_link).to be_present
      end
    end

    describe '#archive!' do
      it 'archives the review' do
        vod_review.archive!
        expect(vod_review.status).to eq('archived')
      end
    end

    describe '#make_public!' do
      it 'makes the review public' do
        vod_review.make_public!
        expect(vod_review.is_public).to be true
        expect(vod_review.share_link).to be_present
      end
    end

    describe '#make_private!' do
      it 'makes the review private' do
        vod_review.update(is_public: true)
        vod_review.make_private!
        expect(vod_review.is_public).to be false
      end
    end

    describe '#timestamp_count' do
      it 'returns the count of timestamps' do
        create_list(:vod_timestamp, 3, vod_review: vod_review)
        expect(vod_review.timestamp_count).to eq(3)
      end
    end

    describe '#important_timestamps' do
      it 'returns only high and critical timestamps' do
        create(:vod_timestamp, vod_review: vod_review, importance: 'high')
        create(:vod_timestamp, vod_review: vod_review, importance: 'critical')
        create(:vod_timestamp, vod_review: vod_review, importance: 'low')

        expect(vod_review.important_timestamps.count).to eq(2)
      end
    end

    describe 'player sharing' do
      let(:player1) { create(:player, organization: vod_review.organization) }
      let(:player2) { create(:player, organization: vod_review.organization) }

      describe '#share_with_player!' do
        it 'adds player to shared_with_players' do
          vod_review.share_with_player!(player1.id)
          expect(vod_review.shared_with_players).to include(player1.id)
        end

        it 'does not duplicate players' do
          vod_review.share_with_player!(player1.id)
          vod_review.share_with_player!(player1.id)
          expect(vod_review.shared_with_players.count(player1.id)).to eq(1)
        end
      end

      describe '#unshare_with_player!' do
        it 'removes player from shared_with_players' do
          vod_review.update(shared_with_players: [player1.id, player2.id])
          vod_review.unshare_with_player!(player1.id)
          expect(vod_review.shared_with_players).not_to include(player1.id)
          expect(vod_review.shared_with_players).to include(player2.id)
        end
      end

      describe '#share_with_all_players!' do
        it 'shares with all organization players' do
          player1
          player2
          vod_review.share_with_all_players!
          expect(vod_review.shared_with_players).to include(player1.id, player2.id)
        end
      end
    end
  end
end
