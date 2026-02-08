# frozen_string_literal: true

class CreateSupportTickets < ActiveRecord::Migration[7.2]
  def change
    create_table :support_tickets, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.references :organization, type: :uuid, null: false, foreign_key: true
      t.references :assigned_to, type: :uuid, foreign_key: { to_table: :users }

      t.string :subject, null: false
      t.text :description, null: false
      t.string :category, null: false # technical, feature_request, billing, riot_integration
      t.string :priority, default: 'medium', null: false # low, medium, high, urgent
      t.string :status, default: 'open', null: false # open, in_progress, waiting_client, resolved, closed

      # Contextual data
      t.string :page_url # URL where ticket was created
      t.jsonb :context_data, default: {} # Additional context (error messages, browser info, etc)

      # Chatbot interaction
      t.boolean :chatbot_attempted, default: false
      t.jsonb :chatbot_suggestions, default: []

      # Metrics
      t.datetime :first_response_at
      t.datetime :resolved_at
      t.datetime :closed_at

      t.timestamps
      t.datetime :deleted_at
    end

    add_index :support_tickets, :status
    add_index :support_tickets, :category
    add_index :support_tickets, :priority
    add_index :support_tickets, :deleted_at
    add_index :support_tickets, [:organization_id, :status]
    add_index :support_tickets, [:assigned_to_id, :status]
  end
end
