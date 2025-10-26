class AddProfessionalNameToPlayers < ActiveRecord::Migration[7.2]
  def change
    add_column :players, :professional_name, :string, comment: 'Professional/competitive IGN used in tournaments (e.g., "Titan" for paiN Gaming)'
    add_index :players, :professional_name
  end
end
