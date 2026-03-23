# frozen_string_literal: true

# Tracks per-user upvotes on feedback items (unique per user per feedback).
class FeedbackVote < ApplicationRecord
  belongs_to :feedback
  belongs_to :user

  validates :user_id, uniqueness: { scope: :feedback_id, message: 'already voted on this feedback' }
end
