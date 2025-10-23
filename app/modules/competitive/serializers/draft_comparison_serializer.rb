# frozen_string_literal: true

module Competitive
  module Serializers
    class DraftComparisonSerializer < Blueprinter::Base
      fields :similarity_score,
             :composition_winrate,
             :meta_score,
             :insights,
             :patch,
             :analyzed_at

      field :similar_matches do |comparison|
        comparison[:similar_matches]
      end

      field :summary do |comparison|
        {
          total_similar_matches: comparison[:similar_matches]&.size || 0,
          avg_similarity: comparison[:similarity_score],
          meta_alignment: comparison[:meta_score],
          expected_winrate: comparison[:composition_winrate]
        }
      end
    end
  end
end
