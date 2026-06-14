# frozen_string_literal: true

class AddProfessionalNameToScoutingTargets < ActiveRecord::Migration[7.1]
  def change
    add_column :scouting_targets, :professional_name, :string,
               comment: 'Competitive tournament IGN as indexed in Leaguepedia/ES. ' \
                        'Join key for competitive_profile lookups. ' \
                        'Distinct from summoner_name (Riot ID) which diverges from historical tournament names.'
    add_index :scouting_targets, :professional_name,
              name: 'idx_scouting_targets_professional_name',
              where: 'professional_name IS NOT NULL'
  end
end
