# frozen_string_literal: true

# Tabela global de win-rate entre pares de campeões.
# Sem organization_id e sem políticas RLS — agrega dados públicos de torneios competitivos
# de todas as organizações. Intencional por design (ver PENDING.md P-03).
class CreateAiChampionMatrices < ActiveRecord::Migration[7.2]
  def change
    create_table :ai_champion_matrices, id: :uuid do |t|
      t.string :champion_a, null: false
      t.string :champion_b, null: false
      t.integer :wins_a, default: 0, null: false
      t.integer :total_games, default: 0, null: false
      t.string :patch
      t.string :league
      t.timestamps
    end

    add_index :ai_champion_matrices,
              [:champion_a, :champion_b, :patch, :league],
              unique: true,
              name: 'index_ai_champion_matrices_unique',
              where: "patch IS NOT NULL AND league IS NOT NULL"

    add_index :ai_champion_matrices,
              [:champion_a, :champion_b],
              name: 'index_ai_champion_matrices_on_pair'
  end
end
