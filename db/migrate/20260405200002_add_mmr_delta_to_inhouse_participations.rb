# frozen_string_literal: true

class AddMmrDeltaToInhouseParticipations < ActiveRecord::Migration[7.2]
  def change
    add_column :inhouse_participations, :mmr_delta, :integer
  end
end
