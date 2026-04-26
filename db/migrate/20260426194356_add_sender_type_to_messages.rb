# frozen_string_literal: true

class AddSenderTypeToMessages < ActiveRecord::Migration[7.2]
  def change
    add_column :messages, :sender_type, :string, default: 'User', null: false
  end
end
