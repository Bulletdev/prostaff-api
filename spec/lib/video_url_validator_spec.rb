# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/video_url_validator'

RSpec.describe VideoUrlValidator do
  describe '.allowed?' do
    context 'with YouTube URLs' do
      it 'returns true for youtube.com' do
        expect(described_class.allowed?('https://youtube.com/watch?v=abc')).to be true
      end

      it 'returns true for www.youtube.com' do
        expect(described_class.allowed?('https://www.youtube.com/watch?v=abc')).to be true
      end

      it 'returns true for youtu.be' do
        expect(described_class.allowed?('https://youtu.be/abc123')).to be true
      end
    end

    context 'with Twitch URLs' do
      it 'returns true for twitch.tv' do
        expect(described_class.allowed?('https://twitch.tv/videos/123456')).to be true
      end

      it 'returns true for clips.twitch.tv' do
        expect(described_class.allowed?('https://clips.twitch.tv/SomeClipSlug')).to be true
      end
    end

    context 'with malicious or unknown URLs' do
      it 'returns false for a domain that contains youtube.com as a suffix attack' do
        expect(described_class.allowed?('https://malicious-youtube.com/watch')).to be false
      end

      it 'returns false when the allowed domain is used as a subdirectory trick' do
        expect(described_class.allowed?('https://malicious-youtube.com.evil.com/path')).to be false
      end

      it 'returns false for an unrelated domain' do
        expect(described_class.allowed?('https://vimeo.com/123456')).to be false
      end

      it 'returns false for a direct file link' do
        expect(described_class.allowed?('https://cdn.example.com/video.mp4')).to be false
      end
    end
  end

  describe '.provider_for' do
    it "returns 'youtube' for youtube.com URLs" do
      expect(described_class.provider_for('https://www.youtube.com/watch?v=abc')).to eq('youtube')
    end

    it "returns 'youtube' for youtu.be URLs" do
      expect(described_class.provider_for('https://youtu.be/abc123')).to eq('youtube')
    end

    it "returns 'twitch' for twitch.tv URLs" do
      expect(described_class.provider_for('https://www.twitch.tv/videos/123')).to eq('twitch')
    end

    it "returns 'twitch' for clips.twitch.tv URLs" do
      expect(described_class.provider_for('https://clips.twitch.tv/SomeClip')).to eq('twitch')
    end

    it "returns 'direct' for an unknown domain" do
      expect(described_class.provider_for('https://vimeo.com/123456')).to eq('direct')
    end

    it "returns 'direct' for a raw file URL" do
      expect(described_class.provider_for('https://cdn.example.com/match.mp4')).to eq('direct')
    end
  end

  describe '.host_for' do
    it 'returns the downcased host for a valid URL' do
      expect(described_class.host_for('https://WWW.YouTube.COM/watch?v=abc')).to eq('www.youtube.com')
    end

    it 'returns nil for a malformed URL' do
      expect(described_class.host_for('not a url :// %%')).to be_nil
    end

    it 'returns nil for an empty string' do
      expect(described_class.host_for('')).to be_nil
    end
  end
end
