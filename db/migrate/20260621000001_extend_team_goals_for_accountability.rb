# frozen_string_literal: true

class ExtendTeamGoalsForAccountability < ActiveRecord::Migration[7.2]
  def change
    change_table :team_goals, bulk: true do |t|
      t.string  :metric_key
      t.string  :comparator      # gte | lte | eq
      t.string  :assignable_type # "Player" | "User" (polymorphic partner to assigned_to_id)
      t.string  :origin_type     # "VodTimestamp" | "AnalyticsBenchmark" | nil
      t.uuid    :origin_id
      t.date    :due_date
      t.uuid    :updated_by_id
    end

    add_index :team_goals, :metric_key
    add_index :team_goals, :due_date
    add_index :team_goals, %i[organization_id metric_key],
              name: 'idx_team_goals_org_metric_key',
              where: 'metric_key IS NOT NULL'
  end
end
