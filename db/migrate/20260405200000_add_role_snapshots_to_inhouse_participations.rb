# frozen_string_literal: true

class AddRoleSnapshotsToInhouseParticipations < ActiveRecord::Migration[7.2]
  def change
    add_column :inhouse_participations, :role,         :string
    add_column :inhouse_participations, :mu_snapshot,  :float
    add_column :inhouse_participations, :sigma_snapshot, :float
  end
end
