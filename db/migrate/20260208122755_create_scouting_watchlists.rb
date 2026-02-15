# frozen_string_literal: true

class CreateScoutingWatchlists < ActiveRecord::Migration[7.1]
  def change
    create_table :scouting_watchlists, id: :uuid do |t|
      t.references :organization, null: false, type: :uuid, foreign_key: true
      t.references :scouting_target, null: false, type: :uuid, foreign_key: true
      t.references :added_by, null: false, type: :uuid, foreign_key: { to_table: :users }
      t.references :assigned_to, type: :uuid, foreign_key: { to_table: :users }

      t.string :priority, default: 'medium', null: false
      t.string :status, default: 'watching', null: false
      t.text :notes
      t.datetime :last_reviewed
      t.jsonb :metadata, default: {}, null: false

      t.timestamps

      # Ensure one watchlist entry per org per target
      t.index %i[organization_id scouting_target_id], unique: true, name: 'index_watchlists_on_org_and_target'
      t.index :priority
      t.index :status
      t.index :last_reviewed
    end

    # Enable RLS on watchlists table
    reversible do |dir|
      dir.up do
        execute <<-SQL
          ALTER TABLE scouting_watchlists ENABLE ROW LEVEL SECURITY;

          -- Policy: Users can only see watchlists from their organization
          CREATE POLICY scouting_watchlists_org_isolation ON scouting_watchlists
            USING (organization_id::text = current_setting('app.current_organization_id', true));

          -- Policy: Allow inserts for authenticated users in their org
          CREATE POLICY scouting_watchlists_org_insert ON scouting_watchlists
            FOR INSERT
            WITH CHECK (organization_id::text = current_setting('app.current_organization_id', true));

          -- Policy: Allow updates for authenticated users in their org
          CREATE POLICY scouting_watchlists_org_update ON scouting_watchlists
            FOR UPDATE
            USING (organization_id::text = current_setting('app.current_organization_id', true));

          -- Policy: Allow deletes for authenticated users in their org
          CREATE POLICY scouting_watchlists_org_delete ON scouting_watchlists
            FOR DELETE
            USING (organization_id::text = current_setting('app.current_organization_id', true));
        SQL
      end

      dir.down do
        execute <<-SQL
          DROP POLICY IF EXISTS scouting_watchlists_org_delete ON scouting_watchlists;
          DROP POLICY IF EXISTS scouting_watchlists_org_update ON scouting_watchlists;
          DROP POLICY IF EXISTS scouting_watchlists_org_insert ON scouting_watchlists;
          DROP POLICY IF EXISTS scouting_watchlists_org_isolation ON scouting_watchlists;

          ALTER TABLE scouting_watchlists DISABLE ROW LEVEL SECURITY;
        SQL
      end
    end
  end
end
