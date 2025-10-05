class VodTimestampSerializer < Blueprinter::Base
  identifier :id

  fields :timestamp_seconds, :category, :importance, :title,
         :description, :created_at, :updated_at

  field :formatted_timestamp do |timestamp|
    seconds = timestamp.timestamp_seconds
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    secs = seconds % 60

    if hours > 0
      format('%02d:%02d:%02d', hours, minutes, secs)
    else
      format('%02d:%02d', minutes, secs)
    end
  end

  association :vod_review, blueprint: VodReviewSerializer
  association :target_player, blueprint: PlayerSerializer
  association :created_by, blueprint: UserSerializer
end
