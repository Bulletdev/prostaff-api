# frozen_string_literal: true

class AddWinsLossesToInhouseParticipations < ActiveRecord::Migration[7.2]
  def change
    add_column :inhouse_participations, :wins, :integer, default: 0, null: false
    add_column :inhouse_participations, :losses, :integer, default: 0, null: false
  end
end
