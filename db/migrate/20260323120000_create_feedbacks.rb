# frozen_string_literal: true

class CreateFeedbacks < ActiveRecord::Migration[7.1]
  def change
    create_table :feedbacks do |t|
      t.references :user,         null: true,  foreign_key: true, type: :uuid
      t.references :organization, null: true,  foreign_key: true, type: :uuid
      t.string     :category,     null: false
      t.string     :title,        null: false
      t.text       :description,  null: false
      t.integer    :rating
      t.string     :status,       null: false, default: 'open'

      t.timestamps
    end

    add_index :feedbacks, :category
    add_index :feedbacks, :status
  end
end
