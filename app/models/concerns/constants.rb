# frozen_string_literal: true

module Constants
  # League of Legends regions
  REGIONS = %w[BR NA EUW EUNE KR JP OCE LAN LAS RU TR].freeze

  # Organization related constants
  module Organization
    TIERS = %w[tier_3_amateur tier_2_semi_pro tier_1_professional].freeze
    SUBSCRIPTION_PLANS = %w[free amateur semi_pro professional enterprise].freeze
    SUBSCRIPTION_STATUSES = %w[active inactive trial expired].freeze

    TIER_NAMES = {
      'tier_3_amateur' => 'Amateur',
      'tier_2_semi_pro' => 'Semi-Pro',
      'tier_1_professional' => 'Professional'
    }.freeze

    SUBSCRIPTION_PLAN_NAMES = {
      'free' => 'Free',
      'amateur' => 'Amateur',
      'semi_pro' => 'Semi-Pro',
      'professional' => 'Professional',
      'enterprise' => 'Enterprise'
    }.freeze
  end

  # User roles
  module User
    ROLES = %w[owner admin coach analyst viewer].freeze

    ROLE_NAMES = {
      'owner' => 'Owner',
      'admin' => 'Administrator',
      'coach' => 'Coach',
      'analyst' => 'Analyst',
      'viewer' => 'Viewer'
    }.freeze
  end

  # Player related constants
  module Player
    ROLES = %w[top jungle mid adc support].freeze
    STATUSES = %w[active inactive benched trial].freeze
    QUEUE_RANKS = %w[I II III IV].freeze
    QUEUE_TIERS = %w[IRON BRONZE SILVER GOLD PLATINUM EMERALD DIAMOND MASTER GRANDMASTER CHALLENGER].freeze

    ROLE_NAMES = {
      'top' => 'Top',
      'jungle' => 'Jungle',
      'mid' => 'Mid',
      'adc' => 'ADC',
      'support' => 'Support'
    }.freeze

    STATUS_NAMES = {
      'active' => 'Active',
      'inactive' => 'Inactive',
      'benched' => 'Benched',
      'trial' => 'Trial'
    }.freeze
  end

  # Match related constants
  module Match
    TYPES = %w[official scrim tournament].freeze
    SIDES = %w[blue red].freeze

    TYPE_NAMES = {
      'official' => 'Official Match',
      'scrim' => 'Scrim',
      'tournament' => 'Tournament'
    }.freeze

    SIDE_NAMES = {
      'blue' => 'Blue Side',
      'red' => 'Red Side'
    }.freeze
  end

  # Scrim related constants
  module Scrim
    TYPES = %w[practice vod_review tournament_prep].freeze
    FOCUS_AREAS = %w[draft macro teamfight laning objectives vision communication].freeze
    VISIBILITY_LEVELS = %w[internal_only coaching_staff full_team].freeze

    TYPE_NAMES = {
      'practice' => 'Practice',
      'vod_review' => 'VOD Review',
      'tournament_prep' => 'Tournament Preparation'
    }.freeze

    FOCUS_AREA_NAMES = {
      'draft' => 'Draft',
      'macro' => 'Macro Play',
      'teamfight' => 'Team Fighting',
      'laning' => 'Laning Phase',
      'objectives' => 'Objective Control',
      'vision' => 'Vision Control',
      'communication' => 'Communication'
    }.freeze

    VISIBILITY_NAMES = {
      'internal_only' => 'Internal Only',
      'coaching_staff' => 'Coaching Staff',
      'full_team' => 'Full Team'
    }.freeze
  end

  # Competitive match constants
  module CompetitiveMatch
    FORMATS = %w[BO1 BO3 BO5].freeze
    SIDES = Match::SIDES # Reuse from Match

    FORMAT_NAMES = {
      'BO1' => 'Best of 1',
      'BO3' => 'Best of 3',
      'BO5' => 'Best of 5'
    }.freeze
  end

  # Opponent team constants
  module OpponentTeam
    TIERS = %w[tier_1 tier_2 tier_3].freeze

    TIER_NAMES = {
      'tier_1' => 'Professional',
      'tier_2' => 'Semi-Pro',
      'tier_3' => 'Amateur'
    }.freeze
  end

  # Schedule constants
  module Schedule
    EVENT_TYPES = %w[match scrim practice meeting review].freeze
    STATUSES = %w[scheduled ongoing completed cancelled].freeze

    EVENT_TYPE_NAMES = {
      'match' => 'Match',
      'scrim' => 'Scrim',
      'practice' => 'Practice',
      'meeting' => 'Meeting',
      'review' => 'Review'
    }.freeze

    STATUS_NAMES = {
      'scheduled' => 'Scheduled',
      'ongoing' => 'Ongoing',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled'
    }.freeze
  end

  # Team goal constants
  module TeamGoal
    CATEGORIES = %w[performance rank tournament skill].freeze
    METRIC_TYPES = %w[win_rate kda cs_per_min vision_score damage_share rank_climb].freeze
    STATUSES = %w[active completed failed cancelled].freeze

    CATEGORY_NAMES = {
      'performance' => 'Performance',
      'rank' => 'Rank',
      'tournament' => 'Tournament',
      'skill' => 'Skill'
    }.freeze

    METRIC_TYPE_NAMES = {
      'win_rate' => 'Win Rate',
      'kda' => 'KDA',
      'cs_per_min' => 'CS/Min',
      'vision_score' => 'Vision Score',
      'damage_share' => 'Damage Share',
      'rank_climb' => 'Rank Climb'
    }.freeze

    STATUS_NAMES = {
      'active' => 'Active',
      'completed' => 'Completed',
      'failed' => 'Failed',
      'cancelled' => 'Cancelled'
    }.freeze
  end

  # VOD Review constants
  module VodReview
    TYPES = %w[team individual opponent].freeze
    STATUSES = %w[draft published archived].freeze

    TYPE_NAMES = {
      'team' => 'Team Review',
      'individual' => 'Individual Review',
      'opponent' => 'Opponent Review'
    }.freeze

    STATUS_NAMES = {
      'draft' => 'Draft',
      'published' => 'Published',
      'archived' => 'Archived'
    }.freeze
  end

  # VOD Timestamp constants
  module VodTimestamp
    CATEGORIES = %w[mistake good_play team_fight objective laning].freeze
    IMPORTANCE_LEVELS = %w[low normal high critical].freeze
    TARGET_TYPES = %w[player team opponent].freeze

    CATEGORY_NAMES = {
      'mistake' => 'Mistake',
      'good_play' => 'Good Play',
      'team_fight' => 'Team Fight',
      'objective' => 'Objective',
      'laning' => 'Laning'
    }.freeze

    IMPORTANCE_NAMES = {
      'low' => 'Low',
      'normal' => 'Normal',
      'high' => 'High',
      'critical' => 'Critical'
    }.freeze

    TARGET_TYPE_NAMES = {
      'player' => 'Player',
      'team' => 'Team',
      'opponent' => 'Opponent'
    }.freeze
  end

  # Scouting target constants
  module ScoutingTarget
    STATUSES = %w[watching contacted negotiating rejected signed].freeze
    PRIORITIES = %w[low medium high critical].freeze

    STATUS_NAMES = {
      'watching' => 'Watching',
      'contacted' => 'Contacted',
      'negotiating' => 'Negotiating',
      'rejected' => 'Rejected',
      'signed' => 'Signed'
    }.freeze

    PRIORITY_NAMES = {
      'low' => 'Low',
      'medium' => 'Medium',
      'high' => 'High',
      'critical' => 'Critical'
    }.freeze
  end

  # Champion Pool constants
  module ChampionPool
    MASTERY_LEVELS = (1..7).freeze
    PRIORITY_LEVELS = (1..10).freeze

    MASTERY_LEVEL_NAMES = {
      1 => 'Novice',
      2 => 'Beginner',
      3 => 'Intermediate',
      4 => 'Advanced',
      5 => 'Expert',
      6 => 'Master',
      7 => 'Grandmaster'
    }.freeze
  end

  # Region names for display
  REGION_NAMES = {
    'BR' => 'Brazil',
    'NA' => 'North America',
    'EUW' => 'Europe West',
    'EUNE' => 'Europe Nordic & East',
    'KR' => 'Korea',
    'LAN' => 'Latin America North',
    'LAS' => 'Latin America South',
    'OCE' => 'Oceania',
    'RU' => 'Russia',
    'TR' => 'Turkey',
    'JP' => 'Japan'
  }.freeze
end
