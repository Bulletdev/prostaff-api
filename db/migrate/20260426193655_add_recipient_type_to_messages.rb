class AddRecipientTypeToMessages < ActiveRecord::Migration[7.2]
  def change
    add_column :messages, :recipient_type, :string, default: 'User', null: false
  end
end
