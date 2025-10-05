class VodReviewSerializer < Blueprinter::Base
  identifier :id

  fields :title, :vod_url, :vod_platform, :game_start_timestamp,
         :status, :notes, :created_at, :updated_at

  field :timestamps_count do |vod_review, options|
    options[:include_timestamps_count] ? vod_review.vod_timestamps.count : nil
  end

  association :organization, blueprint: OrganizationSerializer
  association :match, blueprint: MatchSerializer
  association :reviewed_by, blueprint: UserSerializer
end
