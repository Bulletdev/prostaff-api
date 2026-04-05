# frozen_string_literal: true

# Suggests compatible scrim opponents based on region, tier, and availability.
class MatchSuggestionService
  ADJACENT_TIERS = {
    'amateur' => %w[amateur semi_pro],
    'semi_pro' => %w[amateur semi_pro professional],
    'professional' => %w[semi_pro professional]
  }.freeze

  def initialize(organization, game: 'league_of_legends', region: nil, limit: 20)
    @organization = organization
    @game = game
    @region = region || organization.region
    @limit = limit
  end

  def suggestions
    candidate_windows = find_candidate_windows
    scored = candidate_windows.map { |window| score_window(window) }
    scored.sort_by { |s| -s[:score] }.first(@limit)
  end

  def available_now
    AvailabilityWindow.unscoped
                      .active
                      .available_now
                      .by_game(@game)
                      .where.not(organization_id: @organization.id)
                      .includes(:organization)
                      .limit(@limit)
                      .map { |w| build_suggestion(w, score_window(w)[:score]) }
  end

  private

  def find_candidate_windows
    AvailabilityWindow.unscoped
                      .active
                      .by_game(@game)
                      .where.not(organization_id: @organization.id)
                      .includes(:organization)
  end

  def score_window(window)
    score = 0
    org = window.organization

    # Tier compatibility
    org_tier = map_subscription_to_tier(org.subscription_plan)
    my_tier  = map_subscription_to_tier(@organization.subscription_plan)
    score += 3 if org_tier == my_tier
    score += 1 if ADJACENT_TIERS[my_tier]&.include?(org_tier)

    # Region match
    score += 2 if org.region == @region

    # Window preference alignment
    score += 1 if window.tier_preference == 'any' || (window.tier_preference == 'same' && org_tier == my_tier)

    # Recent activity bonus (org has been active)
    score += 1 if org.updated_at > 7.days.ago

    build_suggestion(window, score)
  end

  def build_suggestion(window, score)
    org = window.organization
    {
      score: score,
      organization: {
        id: org.id,
        name: org.name,
        slug: org.slug,
        region: org.region,
        tier: map_subscription_to_tier(org.subscription_plan),
        public_tagline: org.try(:public_tagline),
        discord_invite_url: org.try(:discord_invite_url)
      },
      availability_window: {
        id: window.id,
        day_of_week: window.day_of_week,
        day_name: window.day_name,
        time_range: window.time_range_display,
        start_hour: window.start_hour,
        end_hour: window.end_hour,
        timezone: window.timezone
      }
    }
  end

  def map_subscription_to_tier(plan)
    case plan
    when 'professional', 'enterprise' then 'professional'
    when 'semi_pro' then 'semi_pro'
    else 'amateur'
    end
  end
end
