# == Schema Information
#
# Table name: leads
#
#  id         :integer          not null, primary key
#  payload    :jsonb
#  email      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  chat_id    :integer
#
# Indexes
#
#  index_leads_on_chat_id  (chat_id)
#

class Lead < ApplicationRecord
  belongs_to :chat, optional: true

  # Scopes for easy filtering
  scope :with_email, -> { where.not(email: nil) }
  scope :hot_leads, -> { where("(payload->>'lead_score')::integer >= ?", 80) }
  scope :high_score, -> { where("(payload->>'lead_score')::integer >= ?", 60) }
  scope :with_appointments, -> { where("payload->'appointments'->>'requested' = ?", 'true') }
  
  # Source-based scopes
  scope :voice_calls, -> { where("payload->>'source' LIKE ?", '%voice%') }
  scope :chat_leads, -> { where("payload->>'source' NOT LIKE ? OR payload->>'source' IS NULL", '%voice%') }
  
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
  
  # Source detection methods
  def source
    payload['source'] || 'chat'
  end
  
  def is_voice_call?
    source.include?('voice') || source.include?('call')
  end
  
  def is_chat_lead?
    !is_voice_call?
  end
  
  def source_display
    if is_voice_call?
      'Voice Call'
    else
      'Web Chat'
    end
  end
  
  def source_icon
    if is_voice_call?
      'phone'
    else
      'chat'
    end
  end
  
  def source_color_class
    if is_voice_call?
      'bg-purple-100 text-purple-800'
    else
      'bg-blue-100 text-blue-800'
    end
  end
  
  def transcription_sid
    payload['transcription_sid']
  end
end
