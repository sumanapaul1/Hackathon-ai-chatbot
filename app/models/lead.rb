# == Schema Information
#
# Table name: leads
#
#  id         :integer          not null, primary key
#  email      :string
#  payload    :jsonb
#  chat_id    :bigint           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_leads_on_chat_id  (chat_id)
#

class Lead < ApplicationRecord
  belongs_to :chat

  # Scopes for easy filtering
  scope :with_email, -> { where.not(email: nil) }
  scope :hot_leads, -> { where("(payload->>'lead_score')::integer >= ?", 80) }
  scope :high_score, -> { where("(payload->>'lead_score')::integer >= ?", 60) }
  scope :with_appointments, -> { where("payload->'appointments'->>'requested' = ?", 'true') }
  
  # Helper methods for accessing payload data
  def contact_name
    payload.dig('contact_info', 'name')
  end
  
  def contact_phone
    payload.dig('contact_info', 'phone')
  end
  
  def lead_score
    payload['lead_score']&.to_i || 0
  end
  
  def conversation_outcome
    payload.dig('conversation_summary', 'outcome')
  end
  
  def interests
    payload['interests'] || []
  end
  
  def has_appointment?
    payload.dig('appointments', 'requested') == true
  end
  
  def appointment_status
    payload.dig('appointments', 'status')
  end
  
  def message_count
    payload['message_count']&.to_i || 0
  end
  
  def chat_duration_minutes
    payload['chat_duration']&.to_f || 0
  end
end
