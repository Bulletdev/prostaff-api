# frozen_string_literal: true

require 'uri'

# Validates and identifies video hosting providers for VOD review URLs.
#
# Supports YouTube (youtube.com, youtu.be) and Twitch (twitch.tv).
# Any URL that does not match a known provider is considered 'direct'.
#
# @example Check if a URL is from an allowed provider
#   VideoUrlValidator.allowed?('https://www.youtube.com/watch?v=abc') # => true
#   VideoUrlValidator.allowed?('https://evil.com/fake-youtube.com')   # => false
#
# @example Get the provider name
#   VideoUrlValidator.provider_for('https://youtu.be/abc')    # => 'youtube'
#   VideoUrlValidator.provider_for('https://twitch.tv/clips') # => 'twitch'
#   VideoUrlValidator.provider_for('https://other.com/video') # => 'direct'
module VideoUrlValidator
  SUFFIXES = {
    'youtube' => %w[youtube.com youtu.be],
    'twitch'  => %w[twitch.tv]
  }.freeze

  # Returns true if the URL host matches a known allowed provider.
  #
  # @param url [String] the video URL to check
  # @return [Boolean]
  def self.allowed?(url)
    host = host_for(url)
    return false unless host

    SUFFIXES.values.flatten.any? { |s| host == s || host.end_with?(".#{s}") }
  end

  # Returns the provider name for the given URL.
  #
  # @param url [String] the video URL
  # @return [String] one of 'youtube', 'twitch', or 'direct'
  def self.provider_for(url)
    host = host_for(url)
    return 'direct' unless host

    SUFFIXES.each do |provider, suffixes|
      return provider if suffixes.any? { |s| host == s || host.end_with?(".#{s}") }
    end

    'direct'
  end

  # Extracts and downcases the host from a URL string.
  #
  # @param url [String] the URL to parse
  # @return [String, nil] the normalized host or nil if the URL is malformed
  def self.host_for(url)
    URI.parse(url).host&.downcase
  rescue URI::Error
    nil
  end
end
