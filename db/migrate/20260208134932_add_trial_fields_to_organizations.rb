class AddTrialFieldsToOrganizations < ActiveRecord::Migration[7.2]
  def change
    add_column :organizations, :trial_expires_at, :datetime
    add_column :organizations, :trial_started_at, :datetime

    # Add indexes for performance
    add_index :organizations, :trial_expires_at
    add_index :organizations, :subscription_status

    # Add unique constraint to prevent duplicate email registrations
    add_index :users, :email, unique: true, if_not_exists: true
  end
end
