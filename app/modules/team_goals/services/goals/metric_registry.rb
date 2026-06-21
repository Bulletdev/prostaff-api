# frozen_string_literal: true

module Goals
  # Canonical registry of measurable metrics for team goals and contract bonuses.
  #
  # Every metric_key stored on TeamGoal or ContractBonus must appear here.
  # Add new keys here before using them in any model — validations enforce this.
  #
  # Sources:
  #   :rails_analytics  — local query on player_match_stats
  #   :rank_snapshot    — local query on player_rank_snapshots (populated by SyncPlayerJob)
  #   :scraper          — HTTP to ProStaff-Scraper analytics endpoints
  #   :manual           — no auto-resolution; always requires human check-in
  class MetricRegistry
    METRICS = {
      'kda_ratio'              => { source: :rails_analytics, unit: :decimal  },
      'cs_per_min'             => { source: :rails_analytics, unit: :decimal  },
      'vision_score_per_min'   => { source: :rails_analytics, unit: :decimal  },
      'gold_per_min'           => { source: :rails_analytics, unit: :decimal  },
      'damage_per_min'         => { source: :rails_analytics, unit: :decimal  },
      'kill_participation'     => { source: :rails_analytics, unit: :percent  },
      'win_rate'               => { source: :rails_analytics, unit: :percent  },
      'soloq_lp_total'         => { source: :rank_snapshot,   unit: :integer  },
      'soloq_win_rate'         => { source: :rank_snapshot,   unit: :percent  },
      'pro_kda'                => { source: :scraper,         unit: :decimal  },
      'pro_cs_per_min'         => { source: :scraper,         unit: :decimal  },
      'pro_dpm'                => { source: :scraper,         unit: :decimal  },
      'pro_gd15'               => { source: :scraper,         unit: :decimal  },
      'pro_wpm'                => { source: :scraper,         unit: :decimal  },
      'soloq_games_week'       => { source: :manual,          unit: :integer  },
      'vod_review_hours_week'  => { source: :manual,          unit: :decimal  },
      'practice_sessions_week' => { source: :manual,          unit: :integer  }
    }.freeze

    VALID_SOURCES = %i[rails_analytics rank_snapshot scraper manual].freeze

    def self.valid?(key)
      METRICS.key?(key.to_s)
    end

    def self.source_for(key)
      METRICS.dig(key.to_s, :source)
    end

    def self.manual?(key)
      source_for(key) == :manual
    end
  end
end
