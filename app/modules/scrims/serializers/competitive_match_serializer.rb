module Scrims
  class CompetitiveMatchSerializer
    def initialize(competitive_match, options = {})
      @competitive_match = competitive_match
      @options = options
    end

    def as_json
      base_attributes.tap do |hash|
        hash.merge!(detailed_attributes) if @options[:detailed]
      end
    end

    private

    def base_attributes
      {
        id: @competitive_match.id,
        organization_id: @competitive_match.organization_id,
        tournament_name: @competitive_match.tournament_name,
        tournament_display: @competitive_match.tournament_display,
        tournament_stage: @competitive_match.tournament_stage,
        tournament_region: @competitive_match.tournament_region,
        match_date: @competitive_match.match_date,
        match_format: @competitive_match.match_format,
        game_number: @competitive_match.game_number,
        game_label: @competitive_match.game_label,
        our_team_name: @competitive_match.our_team_name,
        opponent_team_name: @competitive_match.opponent_team_name,
        opponent_team: opponent_team_summary,
        victory: @competitive_match.victory,
        result_text: @competitive_match.result_text,
        series_score: @competitive_match.series_score,
        side: @competitive_match.side,
        patch_version: @competitive_match.patch_version,
        meta_relevant: @competitive_match.meta_relevant?,
        created_at: @competitive_match.created_at,
        updated_at: @competitive_match.updated_at
      }
    end

    def detailed_attributes
      {
        external_match_id: @competitive_match.external_match_id,
        match_id: @competitive_match.match_id,
        draft_summary: @competitive_match.draft_summary,
        our_composition: @competitive_match.our_composition,
        opponent_composition: @competitive_match.opponent_composition,
        our_banned_champions: @competitive_match.our_banned_champions,
        opponent_banned_champions: @competitive_match.opponent_banned_champions,
        our_picked_champions: @competitive_match.our_picked_champions,
        opponent_picked_champions: @competitive_match.opponent_picked_champions,
        has_complete_draft: @competitive_match.has_complete_draft?,
        meta_champions: @competitive_match.meta_champions,
        game_stats: @competitive_match.game_stats,
        vod_url: @competitive_match.vod_url,
        external_stats_url: @competitive_match.external_stats_url,
        draft_phase_sequence: @competitive_match.draft_phase_sequence
      }
    end

    def opponent_team_summary
      return nil unless @competitive_match.opponent_team

      {
        id: @competitive_match.opponent_team.id,
        name: @competitive_match.opponent_team.name,
        tag: @competitive_match.opponent_team.tag,
        tier: @competitive_match.opponent_team.tier,
        logo_url: @competitive_match.opponent_team.logo_url
      }
    end
  end
end
