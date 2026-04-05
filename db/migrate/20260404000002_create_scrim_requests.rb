# frozen_string_literal: true

class CreateScrimRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :scrim_requests, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.references :requesting_organization, null: false, foreign_key: { to_table: :organizations }, type: :uuid
      t.references :target_organization, null: false, foreign_key: { to_table: :organizations }, type: :uuid
      t.uuid :requesting_scrim_id                  # Scrim created for requesting org on accept
      t.uuid :target_scrim_id                      # Scrim created for target org on accept
      t.uuid :availability_window_id               # Which window triggered this request
      t.string :status, null: false, default: 'pending' # pending/accepted/declined/expired/cancelled
      t.string :game, null: false, default: 'league_of_legends'
      t.text :message
      t.datetime :proposed_at
      t.datetime :expires_at
      t.timestamps
    end

    # requesting_organization_id e target_organization_id já indexados pelo t.references
    add_index :scrim_requests, :status
    add_index :scrim_requests, %i[requesting_organization_id status]
    add_index :scrim_requests, %i[target_organization_id status]
    add_index :scrim_requests, :expires_at
  end
end
