# frozen_string_literal: true

# == Schema Information
#
# Table name: support_faqs
#
#  id                 :uuid             not null, primary key
#  question           :string           not null
#  answer             :text             not null
#  category           :string           not null
#  locale             :string           default("pt-BR"), not null
#  slug               :string           not null
#  keywords           :text             default([]), is an Array
#  position           :integer          default(0)
#  published          :boolean          default(TRUE)
#  view_count         :integer          default(0)
#  helpful_count      :integer          default(0)
#  not_helpful_count  :integer          default(0)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
class SupportFaq < ApplicationRecord
  CATEGORIES = %w[getting_started riot_integration billing features technical other].freeze
  # Validations
  validates :question, presence: true, length: { minimum: 10, maximum: 300 }
  validates :answer, presence: true, length: { minimum: 20 }
  validates :category, presence: true, inclusion: {
    in: %w[getting_started riot_integration billing features technical other]
  }
  validates :locale, presence: true, inclusion: { in: %w[pt-BR en-US] }
  validates :slug, presence: true, uniqueness: true

  # Scopes
  scope :published, -> { where(published: true) }
  scope :by_category, ->(category) { where(category: category) }
  scope :by_locale, ->(locale) { where(locale: locale) }
  scope :ordered, -> { order(position: :asc, created_at: :desc) }
  scope :search, lambda { |query|
    return all if query.blank?

    where(
      'question ILIKE ? OR answer ILIKE ? OR ? = ANY(keywords)',
      "%#{query}%", "%#{query}%", query.downcase
    )
  }

  # Callbacks
  before_validation :generate_slug, on: :create

  # Instance methods
  def increment_view!
    increment!(:view_count)
  end

  def mark_helpful!
    increment!(:helpful_count)
  end

  def mark_not_helpful!
    increment!(:not_helpful_count)
  end

  def helpfulness_ratio
    total = helpful_count + not_helpful_count
    return 0 if total.zero?

    (helpful_count.to_f / total * 100).round(1)
  end

  private

  def generate_slug
    return if slug.present?

    base_slug = question.parameterize
    self.slug = base_slug

    counter = 1
    while SupportFaq.exists?(slug: slug)
      self.slug = "#{base_slug}-#{counter}"
      counter += 1
    end
  end
end
