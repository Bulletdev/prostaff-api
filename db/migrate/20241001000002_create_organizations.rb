class CreateOrganizations < ActiveRecord::Migration[7.1]
  def change
    create_table :organizations, id: :uuid do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :region, null: false
      t.string :tier
      t.string :subscription_plan
      t.string :subscription_status
      t.string :logo_url
      t.jsonb :settings, default: {}

      t.timestamps
    end

    add_index :organizations, :slug, unique: true
    add_index :organizations, :region
    add_index :organizations, :subscription_plan
  end
end