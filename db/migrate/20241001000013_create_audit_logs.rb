class CreateAuditLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :audit_logs, id: :uuid do |t|
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.references :user, foreign_key: true, type: :uuid

      # Action Info
      t.string :action, null: false
      t.string :entity_type, null: false
      t.uuid :entity_id

      # Changes
      t.jsonb :old_values
      t.jsonb :new_values

      # Request Info
      t.inet :ip_address
      t.text :user_agent

      t.timestamps
    end

    add_index :audit_logs, :entity_type
    add_index :audit_logs, :entity_id
    add_index :audit_logs, :created_at
    add_index :audit_logs, [:entity_type, :entity_id]
  end
end