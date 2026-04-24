# frozen_string_literal: true

class AddNullPairIndexToAiChampionMatrices < ActiveRecord::Migration[7.1]
  def change
    # Partial index covering rows where both patch and league are NULL.
    # The existing index_ai_champion_matrices_unique only covers non-null patch+league.
    # Without this, upsert with ON CONFLICT cannot target the null-patch/league rows.
    add_index :ai_champion_matrices, %i[champion_a champion_b],
              name: 'index_ai_champion_matrices_null_pair',
              unique: true,
              where: 'patch IS NULL AND league IS NULL'
  end
end
