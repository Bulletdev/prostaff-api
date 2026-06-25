# frozen_string_literal: true

class AddOpponentPicksToDraftPlans < ActiveRecord::Migration[7.2]
  def change
    add_column :draft_plans, :opponent_picks, :jsonb, default: [], null: false
  end
end
