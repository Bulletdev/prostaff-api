# frozen_string_literal: true

# HTTP client for the VideoAI service (video analysis pipeline).
#
# All requests are authenticated via a short-lived HS256 JWT signed with
# INTERNAL_JWT_SECRET — the same shared secret used by prostaff-riot-gateway.
#
# @example Submit a video for analysis
#   result = VideoAiClient.create_job(vod_review_id: id, video_url: url)
#   job_id = result[:job_id]
#
# @example Poll job status
#   status = VideoAiClient.get_job(job_id)
#   status[:status]  # "downloading" | "analyzing" | "done" | "failed"
#
# @example Create a clip
#   clip = VideoAiClient.create_clip(video_url: url, start_seconds: 60, end_seconds: 90)
class VideoAiClient
  class Error < StandardError; end

  BASE_URL = ENV.fetch('VIDEOAI_URL', 'http://prostaff-videoai:8001')

  def self.create_job(vod_review_id:, video_url:)
    response = connection.post('/jobs', {
      vod_review_id: vod_review_id,
      video_url: video_url
    }.to_json)

    raise Error, "VideoAI returned #{response.status}" unless response.status == 201

    JSON.parse(response.body, symbolize_names: true)
  end

  def self.get_job(external_job_id)
    response = connection.get("/jobs/#{external_job_id}")
    raise Error, "VideoAI returned #{response.status}" unless response.status == 200

    JSON.parse(response.body, symbolize_names: true)
  end

  def self.create_clip(video_url:, start_seconds:, end_seconds:)
    response = connection.post('/clips', {
      video_url: video_url,
      start_seconds: start_seconds,
      end_seconds: end_seconds
    }.to_json)

    raise Error, "VideoAI returned #{response.status}" unless response.status == 201

    JSON.parse(response.body, symbolize_names: true)
  end

  def self.get_clip(clip_id)
    response = connection.get("/clips/#{clip_id}")
    raise Error, "VideoAI returned #{response.status}" unless response.status == 200

    JSON.parse(response.body, symbolize_names: true)
  end

  private_class_method def self.connection
    Faraday.new(url: BASE_URL) do |f|
      f.headers['Content-Type'] = 'application/json'
      f.headers['Authorization'] = "Bearer #{internal_jwt}"
      f.options.timeout = 30
    end
  end

  private_class_method def self.internal_jwt
    JWT.encode(
      { service: 'prostaff-api', iat: Time.current.to_i },
      ENV['INTERNAL_JWT_SECRET'],
      'HS256'
    )
  end
end
