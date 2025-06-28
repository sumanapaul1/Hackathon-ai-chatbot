class AddStatusToChats < ActiveRecord::Migration[8.0]
  def change
    add_column :chats, :status, :string, default: 'open', null: false
  end
end
