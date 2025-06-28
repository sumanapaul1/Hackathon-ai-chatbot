# == Schema Information
#
# Table name: messages
#
#  id         :integer          not null, primary key
#  chat_id    :integer          not null
#  sender     :string
#  content    :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_messages_on_chat_id  (chat_id)
#

class Message < ApplicationRecord
  belongs_to :chat

  validates :content, presence: true

  def agent?
    sender != "user"
  end
end
