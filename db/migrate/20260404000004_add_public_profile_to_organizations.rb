class AddPublicProfileToOrganizations < ActiveRecord::Migration[7.1]
  def change
    add_column :organizations, :is_public, :boolean, default: false, null: false
    add_column :organizations, :public_tagline, :string, limit: 200
    add_column :organizations, :discord_invite_url, :string
    add_index :organizations, :is_public, where: "(is_public = true)"
  end
end
