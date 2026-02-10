class CreateFantasyWaitlists < ActiveRecord::Migration[7.2]
  def change
    create_table :fantasy_waitlists do |t|
      t.string :email, null: false
      t.bigint :organization_id
      t.boolean :notified, default: false
      t.datetime :subscribed_at

      t.timestamps
    end
    add_index :fantasy_waitlists, :email, unique: true
    add_index :fantasy_waitlists, :organization_id
  end
end
