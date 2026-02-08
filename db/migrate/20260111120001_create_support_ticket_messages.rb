# frozen_string_literal: true

class CreateSupportTicketMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :support_ticket_messages, id: :uuid do |t|
      t.references :support_ticket, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, null: false, foreign_key: true

      t.text :content, null: false
      t.string :message_type, default: 'user', null: false # user, staff, system, chatbot
      t.boolean :is_internal, default: false # Internal notes visible only to staff

      # Attachments (if any)
      t.jsonb :attachments, default: []

      t.timestamps
    end

    add_index :support_ticket_messages, [:support_ticket_id, :created_at]
    add_index :support_ticket_messages, :message_type
  end
end
