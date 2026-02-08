# frozen_string_literal: true

class CreateSupportFaqs < ActiveRecord::Migration[7.2]
  def change
    create_table :support_faqs, id: :uuid do |t|
      t.string :question, null: false
      t.text :answer, null: false
      t.string :category, null: false # getting_started, riot_integration, billing, features, technical
      t.string :locale, default: 'pt-BR', null: false

      # SEO and search
      t.string :slug, null: false
      t.text :keywords, array: true, default: []

      # Ordering and visibility
      t.integer :position, default: 0
      t.boolean :published, default: true

      # Metrics
      t.integer :view_count, default: 0
      t.integer :helpful_count, default: 0
      t.integer :not_helpful_count, default: 0

      t.timestamps
    end

    add_index :support_faqs, :slug, unique: true
    add_index :support_faqs, :category
    add_index :support_faqs, :locale
    add_index :support_faqs, [:published, :position]
  end
end
