# frozen_string_literal: true

FactoryBot.define do
  factory :vod_analysis_job do
    association :vod_review

    status { 'pending' }
    progress { 0 }
    suggested_timestamps { [] }
    external_job_id { nil }
    error_message { nil }

    trait :queued do
      status { 'queued' }
      external_job_id { SecureRandom.uuid }
    end

    trait :downloading do
      status { 'downloading' }
      external_job_id { SecureRandom.uuid }
      progress { 20 }
    end

    trait :analyzing do
      status { 'analyzing' }
      external_job_id { SecureRandom.uuid }
      progress { 60 }
    end

    trait :done do
      status { 'done' }
      external_job_id { SecureRandom.uuid }
      progress { 100 }
      suggested_timestamps do
        [
          {
            'id' => 'suggestion-0',
            'start_seconds' => 120,
            'end_seconds' => 135,
            'reason' => 'teamfight near dragon',
            'confidence' => 0.92
          },
          {
            'id' => 'suggestion-1',
            'start_seconds' => 340,
            'end_seconds' => 360,
            'reason' => 'baron steal',
            'confidence' => 0.75
          }
        ]
      end
    end

    trait :failed do
      status { 'failed' }
      external_job_id { SecureRandom.uuid }
      error_message { 'VideoAI service unavailable' }
    end
  end
end
