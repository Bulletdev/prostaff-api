# frozen_string_literal: true

module MatchFingerprint
  # Generates a stable fingerprint for a physical game based on attributes that
  # are source-agnostic. Used to detect duplicates when the same game arrives
  # from two import pipelines (Riot API numeric ID and Leaguepedia textual ID)
  # with different external_match_id values.
  #
  # @param org_id [String] organization UUID
  # @param match_date [DateTime, nil]
  # @param game_number [Integer, nil] game within the series (1-5)
  # @param opponent_name [String, nil]
  # @return [String, nil] MD5 hex string, or nil when inputs are insufficient
  def generate_fingerprint(org_id, match_date, game_number, opponent_name)
    return nil if match_date.nil? || opponent_name.nil? || opponent_name.strip.empty?

    day = match_date.to_date.to_s
    normalized = opponent_name.strip.downcase
    Digest::MD5.hexdigest("#{org_id}|#{day}|#{game_number || 1}|#{normalized}")
  end

  # Returns true if a record with this fingerprint already exists for the org.
  # Skips the check when the fingerprint cannot be computed (missing inputs).
  #
  # @param organization [Organization]
  # @param match_date [DateTime, nil]
  # @param game_number [Integer, nil]
  # @param opponent_name [String, nil]
  # @return [Boolean]
  def duplicate_by_fingerprint?(organization, match_date, game_number, opponent_name)
    fp = generate_fingerprint(organization.id, match_date, game_number, opponent_name)
    return false if fp.nil?

    organization.competitive_matches.where(game_fingerprint: fp).exists?
  end
end
