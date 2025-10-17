class VodReviewSerializer < Blueprinter::Base
  identifier :id

  fields :title, :description, :review_type, :review_date,
         :video_url, :thumbnail_url, :duration,
         :is_public, :share_link, :shared_with_players,
         :status, :tags, :metadata,
         :created_at, :updated_at

  field :timestamps_count do |vod_review, options|
    options[:include_timestamps_count] ? vod_review.vod_timestamps.count : nil
  end

  association :organization, blueprint: OrganizationSerializer
  association :match, blueprint: MatchSerializer
  association :reviewer, blueprint: UserSerializer
end
