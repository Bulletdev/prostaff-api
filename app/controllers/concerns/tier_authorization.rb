# frozen_string_literal: true

module TierAuthorization
  extend ActiveSupport::Concern

  included do
    before_action :check_tier_access, only: %i[create update]
    before_action :check_match_limit, only: [:create], if: -> { controller_name == 'matches' }
    before_action :check_player_limit, only: [:create], if: -> { controller_name == 'players' }
  end

  private

  def check_tier_access
    feature = controller_feature_name

    return if current_organization.can_access?(feature)

    render_upgrade_required(feature)
  end

  def controller_feature_name
    # Map controller to feature name
    controller_map = {
      'scrims' => 'scrims',
      'opponent_teams' => 'opponent_database',
      'draft_analysis' => 'draft_analysis',
      'team_comp' => 'team_composition',
      'competitive_matches' => 'competitive_data',
      'predictive' => 'predictive_analytics'
    }

    controller_map[controller_name] || controller_name
  end

  def render_upgrade_required(feature)
    required_tier = tier_required_for(feature)

    render json: {
      error: 'Upgrade Required',
      message: "This feature requires #{required_tier} subscription",
      current_tier: current_organization.tier,
      required_tier: required_tier,
      upgrade_url: "#{frontend_url}/pricing",
      feature: feature
    }, status: :forbidden
  end

  def tier_required_for(feature)
    tier_requirements = {
      'scrims' => 'Tier 2 (Semi-Pro)',
      'opponent_database' => 'Tier 2 (Semi-Pro)',
      'draft_analysis' => 'Tier 2 (Semi-Pro)',
      'team_composition' => 'Tier 2 (Semi-Pro)',
      'competitive_data' => 'Tier 1 (Professional)',
      'predictive_analytics' => 'Tier 1 (Professional)',
      'meta_analysis' => 'Tier 1 (Professional)',
      'api_access' => 'Tier 1 (Enterprise)'
    }

    tier_requirements[feature] || 'Unknown'
  end

  def check_match_limit
    return unless current_organization.match_limit_reached?

    render json: {
      error: 'Limit Reached',
      message: 'Monthly match limit reached. Upgrade to increase limit.',
      upgrade_url: "#{frontend_url}/pricing",
      current_limit: current_organization.tier_limits[:max_matches_per_month],
      current_usage: current_organization.tier_limits[:current_monthly_matches]
    }, status: :forbidden
  end

  def check_player_limit
    return unless current_organization.player_limit_reached?

    render json: {
      error: 'Limit Reached',
      message: 'Player limit reached. Upgrade to add more players.',
      upgrade_url: "#{frontend_url}/pricing",
      current_limit: current_organization.tier_limits[:max_players],
      current_usage: current_organization.tier_limits[:current_players]
    }, status: :forbidden
  end

  def frontend_url
    ENV['FRONTEND_URL'] || 'http://localhost:3000'
  end

  # Helper method to check feature access without rendering
  def has_feature_access?(feature_name)
    current_organization.can_access?(feature_name)
  end

  # Helper method to get tier limits
  def current_tier_limits
    current_organization.tier_limits
  end
end
