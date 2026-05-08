# frozen_string_literal: true

FactoryBot.define do
  factory :support_faq do
    sequence(:slug) { |n| "faq-slug-#{n}" }
    question { "#{Faker::Lorem.sentence(word_count: 8)}?" }
    answer { Faker::Lorem.paragraph(sentence_count: 5) }
    category { 'getting_started' }
    locale { 'pt-BR' }
    published { true }
    position { 1 }
    helpful_count { 0 }
    not_helpful_count { 0 }
    view_count { 0 }
  end
end
