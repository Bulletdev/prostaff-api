# frozen_string_literal: true

class AddAvatarUrlToPlayers < ActiveRecord::Migration[7.2]
  def change
    add_column :players, :avatar_url, :string
  end
end
