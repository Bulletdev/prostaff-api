# frozen_string_literal: true

class CreateScrimMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :scrim_messages, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.references :scrim,        null: false, type: :uuid, foreign_key: true
      t.references :user,         null: false, type: :uuid, foreign_key: true
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.text    :content,  null: false
      t.boolean :deleted,  null: false, default: false
      t.datetime :deleted_at

      t.timestamps
    end

    # Composite index for paginated history queries — not created by t.references
    add_index :scrim_messages, %i[scrim_id created_at], name: 'index_scrim_messages_on_scrim_id_and_created_at'
  end
end
