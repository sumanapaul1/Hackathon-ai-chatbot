class MakeChatIdOptionalInLeads < ActiveRecord::Migration[8.0]
  def change
    # Make chat_id nullable to allow voice calls without associated chats
    change_column_null :leads, :chat_id, true
  end
end
