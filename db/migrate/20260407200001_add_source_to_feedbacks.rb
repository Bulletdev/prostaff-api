# frozen_string_literal: true

class AddSourceToFeedbacks < ActiveRecord::Migration[7.1]
  def change
    add_column :feedbacks, :source, :string, null: false, default: 'prostaff'
    add_index  :feedbacks, :source
  end
end
