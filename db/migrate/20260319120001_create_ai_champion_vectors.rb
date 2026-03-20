# frozen_string_literal: true

# Vetores normalizados por campeão (5 dimensões: win_rate, avg_kda, avg_damage_share, avg_gold_share, avg_cs).
# Tabela global, sem organization_id, sem RLS (ver PENDING.md P-03).
# v2: adicionar cc_score e mobility_score via tabela champion_attributes.
class CreateAiChampionVectors < ActiveRecord::Migration[7.2]
  def change
    create_table :ai_champion_vectors, id: :uuid do |t|
      t.string :champion_name, null: false
      t.jsonb :vector_data, null: false, default: []
      t.integer :games_count, default: 0, null: false
      t.timestamps
    end

    add_index :ai_champion_vectors, :champion_name, unique: true
  end
end
