require 'rails_helper'

RSpec.describe VodTimestamp, type: :model do
  describe 'associations' do
    it { should belong_to(:vod_review) }
    it { should belong_to(:target_player).class_name('Player').optional }
    it { should belong_to(:created_by).class_name('User').optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:timestamp_seconds) }
    it { should validate_numericality_of(:timestamp_seconds).is_greater_than_or_equal_to(0) }
    it { should validate_presence_of(:title) }
    it { should validate_length_of(:title).is_at_most(255) }
    it { should validate_inclusion_of(:category).in_array(%w[mistake good_play team_fight objective laning]).allow_blank }
    it { should validate_inclusion_of(:importance).in_array(%w[low normal high critical]) }
    it { should validate_inclusion_of(:target_type).in_array(%w[player team opponent]).allow_blank }
  end

  describe 'scopes' do
    let(:vod_review) { create(:vod_review) }
    let!(:mistake_timestamp) { create(:vod_timestamp, :mistake, vod_review: vod_review) }
    let!(:good_play_timestamp) { create(:vod_timestamp, :good_play, vod_review: vod_review) }
    let!(:critical_timestamp) { create(:vod_timestamp, :critical, vod_review: vod_review) }

    describe '.by_category' do
      it 'filters by category' do
        expect(VodTimestamp.by_category('mistake')).to include(mistake_timestamp)
        expect(VodTimestamp.by_category('mistake')).not_to include(good_play_timestamp)
      end
    end

    describe '.by_importance' do
      it 'filters by importance' do
        expect(VodTimestamp.by_importance('critical')).to include(critical_timestamp)
      end
    end

    describe '.important' do
      it 'returns high and critical timestamps' do
        expect(VodTimestamp.important).to include(critical_timestamp, mistake_timestamp)
        expect(VodTimestamp.important).not_to include(good_play_timestamp)
      end
    end

    describe '.chronological' do
      it 'orders by timestamp_seconds' do
        ts1 = create(:vod_timestamp, vod_review: vod_review, timestamp_seconds: 100)
        ts2 = create(:vod_timestamp, vod_review: vod_review, timestamp_seconds: 50)
        ts3 = create(:vod_timestamp, vod_review: vod_review, timestamp_seconds: 200)

        expect(VodTimestamp.chronological.pluck(:timestamp_seconds)).to eq([50, 100, 200])
      end
    end
  end

  describe 'instance methods' do
    let(:vod_timestamp) { create(:vod_timestamp, timestamp_seconds: 3665) }

    describe '#timestamp_formatted' do
      it 'formats timestamp with hours' do
        expect(vod_timestamp.timestamp_formatted).to eq('1:01:05')
      end

      it 'formats timestamp without hours' do
        vod_timestamp.update(timestamp_seconds: 125)
        expect(vod_timestamp.timestamp_formatted).to eq('2:05')
      end
    end

    describe '#importance_color' do
      it 'returns correct color for each importance' do
        vod_timestamp.update(importance: 'low')
        expect(vod_timestamp.importance_color).to eq('gray')

        vod_timestamp.update(importance: 'normal')
        expect(vod_timestamp.importance_color).to eq('blue')

        vod_timestamp.update(importance: 'high')
        expect(vod_timestamp.importance_color).to eq('orange')

        vod_timestamp.update(importance: 'critical')
        expect(vod_timestamp.importance_color).to eq('red')
      end
    end

    describe '#category_color' do
      it 'returns correct color for each category' do
        vod_timestamp.update(category: 'mistake')
        expect(vod_timestamp.category_color).to eq('red')

        vod_timestamp.update(category: 'good_play')
        expect(vod_timestamp.category_color).to eq('green')

        vod_timestamp.update(category: 'team_fight')
        expect(vod_timestamp.category_color).to eq('purple')
      end
    end

    describe '#category_icon' do
      it 'returns correct icon for each category' do
        vod_timestamp.update(category: 'mistake')
        expect(vod_timestamp.category_icon).to eq('⚠️')

        vod_timestamp.update(category: 'good_play')
        expect(vod_timestamp.category_icon).to eq('✅')

        vod_timestamp.update(category: 'team_fight')
        expect(vod_timestamp.category_icon).to eq('⚔️')
      end
    end

    describe '#target_display' do
      let(:player) { create(:player, summoner_name: 'TestPlayer') }

      it 'returns player name for player target' do
        vod_timestamp.update(target_type: 'player', target_player: player)
        expect(vod_timestamp.target_display).to eq('TestPlayer')
      end

      it 'returns Team for team target' do
        vod_timestamp.update(target_type: 'team')
        expect(vod_timestamp.target_display).to eq('Team')
      end

      it 'returns Opponent for opponent target' do
        vod_timestamp.update(target_type: 'opponent')
        expect(vod_timestamp.target_display).to eq('Opponent')
      end
    end

    describe '#video_url_with_timestamp' do
      it 'adds timestamp to YouTube URL' do
        vod_timestamp.vod_review.update(video_url: 'https://www.youtube.com/watch?v=abc123')
        vod_timestamp.update(timestamp_seconds: 120)
        expect(vod_timestamp.video_url_with_timestamp).to include('t=120s')
      end

      it 'adds timestamp to Twitch URL' do
        vod_timestamp.vod_review.update(video_url: 'https://www.twitch.tv/videos/123456')
        vod_timestamp.update(timestamp_seconds: 120)
        expect(vod_timestamp.video_url_with_timestamp).to include('t=120s')
      end

      it 'returns base URL for other platforms' do
        vod_timestamp.vod_review.update(video_url: 'https://other.com/video')
        expect(vod_timestamp.video_url_with_timestamp).to eq('https://other.com/video')
      end
    end

    describe '#is_important?' do
      it 'returns true for high importance' do
        vod_timestamp.update(importance: 'high')
        expect(vod_timestamp.is_important?).to be true
      end

      it 'returns true for critical importance' do
        vod_timestamp.update(importance: 'critical')
        expect(vod_timestamp.is_important?).to be true
      end

      it 'returns false for normal importance' do
        vod_timestamp.update(importance: 'normal')
        expect(vod_timestamp.is_important?).to be false
      end
    end

    describe '#is_mistake?' do
      it 'returns true for mistake category' do
        vod_timestamp.update(category: 'mistake')
        expect(vod_timestamp.is_mistake?).to be true
      end

      it 'returns false for other categories' do
        vod_timestamp.update(category: 'good_play')
        expect(vod_timestamp.is_mistake?).to be false
      end
    end

    describe '#is_highlight?' do
      it 'returns true for good_play category' do
        vod_timestamp.update(category: 'good_play')
        expect(vod_timestamp.is_highlight?).to be true
      end

      it 'returns false for other categories' do
        vod_timestamp.update(category: 'mistake')
        expect(vod_timestamp.is_highlight?).to be false
      end
    end

    describe 'navigation methods' do
      let(:vod_review) { create(:vod_review) }
      let!(:timestamp1) { create(:vod_timestamp, vod_review: vod_review, timestamp_seconds: 100) }
      let!(:timestamp2) { create(:vod_timestamp, vod_review: vod_review, timestamp_seconds: 200) }
      let!(:timestamp3) { create(:vod_timestamp, vod_review: vod_review, timestamp_seconds: 300) }

      describe '#next_timestamp' do
        it 'returns the next timestamp' do
          expect(timestamp2.next_timestamp).to eq(timestamp3)
        end

        it 'returns nil for last timestamp' do
          expect(timestamp3.next_timestamp).to be_nil
        end
      end

      describe '#previous_timestamp' do
        it 'returns the previous timestamp' do
          expect(timestamp2.previous_timestamp).to eq(timestamp1)
        end

        it 'returns nil for first timestamp' do
          expect(timestamp1.previous_timestamp).to be_nil
        end
      end
    end
  end
end
