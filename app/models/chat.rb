# == Schema Information
#
# Table name: chats
#
#  id         :integer          not null, primary key
#  agent_id   :integer          not null
#  status     :string           default("open"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_chats_on_agent_id  (agent_id)
#

class Chat < ApplicationRecord
  belongs_to :agent
  has_many :messages
  has_many :leads

  # Status constants
  OPEN = 'open'.freeze
  CLOSED = 'closed'.freeze

  # Scopes
  scope :open, -> { where(status: OPEN) }
  scope :closed, -> { where(status: CLOSED) }

  # Instance methods
  def open?
    status == OPEN
  end

  def closed?
    status == CLOSED
  end

  def close!
    update!(status: CLOSED)
  end

  def reopen!
    update!(status: OPEN)
  end

  def create_lead_from_conversation
    extracted_info = extract_lead_information
    
    self.leads.create!(
      email: extracted_info[:email],
      payload: {
        source: 'chat_completion',
        conversation_summary: generate_conversation_summary,
        contact_info: extracted_info[:contact_info],
        interests: extracted_info[:interests],
        appointments: extracted_info[:appointments],
        property_questions: extracted_info[:property_questions],
        chat_duration: calculate_chat_duration,
        message_count: messages.count,
        completed_at: Time.current,
        lead_score: calculate_lead_score(extracted_info)
      }
    )
  end

  def stream_id
    "chat_#{id}"
  end

  def messages_id
    "chat_messages_#{id}"
  end

  def extract_lead_information
    conversation_text = messages.map(&:content).join(' ').downcase
    user_messages_text = messages.where(sender: 'user').pluck(:content).join(' ').downcase
    
    # Extract email from USER messages only
    email_match = user_messages_text.match(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/i)
    email = email_match ? email_match[0] : nil
    
    # Extract phone number from USER messages only
    phone_patterns = [
      /\b\d{3}[-.]?\d{3}[-.]?\d{4}\b/,
      /\b\(\d{3}\)\s?\d{3}[-.]?\d{4}\b/,
      /\b\d{3}\s?\d{3}\s?\d{4}\b/
    ]
    phone = nil
    phone_patterns.each do |pattern|
      match = user_messages_text.match(pattern)
      if match
        phone = match[0]
        break
      end
    end
    
    # Extract name from USER messages only (not assistant messages)  
    name_patterns = [
      /(?:my name is|i'm|i am|this is|call me)\s+([a-zA-Z\s]+?)(?:\s|$|[.,!?])/i,
      /(?:name)\s*[:=]\s*([a-zA-Z\s]+?)(?:\s|$|[.,!?])/i,
      /(?:i'm|i am)\s+([a-zA-Z\s]+?)(?:\s|$|[.,!?])/i
    ]
    name = nil
    name_patterns.each do |pattern|
      match = user_messages_text.match(pattern)
      if match
        candidate_name = match[1].strip.titleize
        # Exclude common AI assistant names and generic terms
        unless ['Tina', 'Assistant', 'Bot', 'Hello', 'Hi', 'Thanks', 'Thank'].include?(candidate_name)
          name = candidate_name
          break
        end
      end
    end
    
    # Extract interests and property preferences
    interests = []
    interests << '1BHK' if conversation_text.include?('1bhk') || conversation_text.include?('one bedroom')
    interests << '2BHK' if conversation_text.include?('2bhk') || conversation_text.include?('two bedroom')
    interests << 'Ground Floor' if conversation_text.include?('ground floor')
    interests << 'Balcony' if conversation_text.include?('balcony')
    interests << 'Swimming Pool' if conversation_text.include?('pool')
    interests << 'Fitness Center' if conversation_text.include?('gym') || conversation_text.include?('fitness')
    interests << 'Pet Friendly' if conversation_text.include?('pet')
    
    # Extract appointment information with more detail
    appointments = extract_appointment_details(conversation_text)
    
    # Create Google Calendar event if appointment is confirmed
    if appointments[:status] == 'confirmed' && email.present?
      create_calendar_event(appointments, email, name, phone, interests)
    end
    
    # Property-related questions
    property_questions = []
    property_questions << 'Pricing' if conversation_text.include?('price') || conversation_text.include?('cost') || conversation_text.include?('rent')
    property_questions << 'Availability' if conversation_text.include?('available') || conversation_text.include?('vacant')
    property_questions << 'Amenities' if conversation_text.include?('amenities') || conversation_text.include?('facilities')
    property_questions << 'Location' if conversation_text.include?('location') || conversation_text.include?('address')
    
    {
      email: email,
      contact_info: {
        name: name,
        phone: phone,
        email: email
      },
      interests: interests,
      appointments: appointments,
      property_questions: property_questions
    }
  end

  private


  def generate_conversation_summary
    user_messages = messages.where(sender: 'user').pluck(:content)
    assistant_messages = messages.where(sender: 'assistant').pluck(:content)
    
    summary = {
      total_messages: messages.count,
      user_messages_count: user_messages.count,
      assistant_messages_count: assistant_messages.count,
      conversation_topics: determine_conversation_topics,
      outcome: determine_conversation_outcome
    }
    
    # Add first and last messages for context
    summary[:first_user_message] = user_messages.first if user_messages.any?
    summary[:last_assistant_message] = assistant_messages.last if assistant_messages.any?
    
    summary
  end

  def determine_conversation_topics
    all_content = messages.pluck(:content).join(' ').downcase
    topics = []
    
    topics << 'floor_plans' if all_content.include?('floor') || all_content.include?('bhk')
    topics << 'pricing' if all_content.include?('price') || all_content.include?('cost')
    topics << 'amenities' if all_content.include?('amenities') || all_content.include?('pool') || all_content.include?('gym')
    topics << 'scheduling' if all_content.include?('tour') || all_content.include?('appointment')
    topics << 'availability' if all_content.include?('available') || all_content.include?('vacant')
    
    topics
  end

  def determine_conversation_outcome
    last_messages = messages.last(3).pluck(:content).join(' ').downcase
    
    return 'appointment_scheduled' if last_messages.include?('confirmed') || last_messages.include?('booked')
    return 'information_provided' if last_messages.include?('thank') || last_messages.include?('help')
    return 'lead_captured' if last_messages.include?('contact') || last_messages.include?('call')
    
    'conversation_completed'
  end

  def calculate_chat_duration
    return 0 if messages.count < 2
    
    first_message = messages.order(:created_at).first
    last_message = messages.order(:created_at).last
    
    ((last_message.created_at - first_message.created_at) / 1.minute).round(2)
  end

  def calculate_lead_score(extracted_info)
    score = 0
    
    # Contact information provided
    score += 30 if extracted_info[:contact_info][:email]
    score += 25 if extracted_info[:contact_info][:phone]
    score += 15 if extracted_info[:contact_info][:name]
    
    # Engagement level
    score += 20 if messages.count >= 5
    score += 10 if messages.count >= 10
    
    # Specific interests
    score += 10 if extracted_info[:interests].any?
    score += 15 if extracted_info[:appointments].present? && extracted_info[:appointments][:requested]
    
    # Property questions indicate serious interest
    score += 5 * extracted_info[:property_questions].count
    
    [score, 100].min # Cap at 100
  end

  def extract_appointment_details(conversation_text)
    appointments = { requested: false, status: 'none' }
    
    if conversation_text.include?('appointment') || conversation_text.include?('tour') || conversation_text.include?('visit')
      appointments[:requested] = true
      
      # Look for specific days mentioned
      days = %w[monday tuesday wednesday thursday friday saturday sunday]
      mentioned_days = days.select { |day| conversation_text.include?(day) }
      
      # Look for time mentions (more comprehensive patterns)
      time_patterns = [
        /\d{1,2}:\d{2}\s*(?:am|pm)/i,
        /\d{1,2}\s*(?:am|pm)/i,
        /\d{1,2}:\d{2}/
      ]
      
      time_matches = []
      time_patterns.each do |pattern|
        time_matches.concat(conversation_text.scan(pattern))
      end
      
      # Extract most recent/specific date and time - USE RECENT MESSAGES FIRST
      latest_messages = messages.last(4).map(&:content).join(' ').downcase
      
      # Look for confirmation patterns in recent messages
      confirmed = latest_messages.include?('confirmed') || 
                 latest_messages.include?('booked') || 
                 latest_messages.include?('scheduled') ||
                 latest_messages.match?(/(?:perfect|great|excellent).*(?:appointment|tour)/)
      
      # Try to extract specific date from full conversation FIRST (most reliable)
      specific_date = extract_appointment_date(conversation_text, mentioned_days)
      
      # If no specific date found, try recent messages  
      if specific_date.nil?
        specific_date = extract_appointment_date(latest_messages, mentioned_days)
      end
      
      # If still no specific date, fallback to next occurrence of mentioned day
      if specific_date.nil? && mentioned_days.any?
        fallback_day = mentioned_days.last
        
        # Calculate next occurrence of the day
        days_names = %w[sunday monday tuesday wednesday thursday friday saturday]
        target_wday = days_names.index(fallback_day.downcase)
        
        if target_wday
          today = Date.current
          days_ahead = ((target_wday - today.wday) % 7)
          days_ahead = 7 if days_ahead == 0 # Next week if it's the same day
          fallback_date = today + days_ahead.days
          specific_date = fallback_date.strftime('%A, %B %-d').downcase
        end
      end
      
      specific_time = extract_appointment_time(latest_messages, time_matches)
      
      appointments.merge!({
        days_mentioned: mentioned_days,
        times_mentioned: time_matches,
        specific_date: specific_date,
        specific_time: specific_time,
        status: confirmed ? 'confirmed' : 'requested'
      })
    end
    
    appointments
  end
  
  def extract_appointment_date(conversation_text, mentioned_days)
    # Look for specific date patterns first (most specific to least specific)
    date_patterns = [
      # Full dates: "Monday, July 3" or "July 3rd"
      /(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday),?\s+(?:january|february|march|april|may|june|july|august|september|october|november|december)\s+\d{1,2}(?:st|nd|rd|th)?/i,
      # Month + Day: "July 3rd", "July 3", "3rd July"
      /(?:january|february|march|april|may|june|july|august|september|october|november|december)\s+\d{1,2}(?:st|nd|rd|th)?/i,
      /\d{1,2}(?:st|nd|rd|th)?\s+(?:january|february|march|april|may|june|july|august|september|october|november|december)/i,
      # Numeric formats: "7/3/2025", "7-3-2025"
      /\d{1,2}\/\d{1,2}\/\d{2,4}/,
      /\d{1,2}-\d{1,2}-\d{2,4}/
    ]
    
    # Check patterns in order of specificity
    date_patterns.each_with_index do |pattern, index|
      match = conversation_text.match(pattern)
      if match
        matched_date = match[0].downcase
        
        # If we found a specific month+day, prefer that over just day names
        if matched_date.match?(/(?:january|february|march|april|may|june|july|august|september|october|november|december)/i)
          # Convert ordinals to clean format
          clean_date = matched_date.gsub(/(\d+)(?:st|nd|rd|th)/, '\1')
          return clean_date
        else
          return matched_date
        end
      end
    end
    
    # No specific date patterns found, return nil (don't fallback to day names)
    # The calling method will handle fallbacks
    nil
  end
  
  def extract_appointment_time(conversation_text, time_matches)
    # Get the most recent time mentioned
    return time_matches.last if time_matches.any?
    
    # Look for implied times
    return '2:00 PM' if conversation_text.include?('afternoon')
    return '10:00 AM' if conversation_text.include?('morning')
    return '11:00 AM' if conversation_text.include?('late morning')
    
    nil
  end
  
  def create_calendar_event(appointments, email, name, phone, interests = [])
    return unless appointments[:specific_date] && appointments[:specific_time]
    
    begin
      calendar_service = GoogleCalendarService.new
      
      appointment_details = {
        customer_name: name || 'Prospective Tenant',
        customer_email: email,
        customer_phone: phone,
        date: appointments[:specific_date],
        time: appointments[:specific_time],
        interests: interests,
        conversation_summary: generate_brief_summary
      }
      
      result = calendar_service.create_tour_appointment(appointment_details)
      
      if result[:success]
        # Store the event ID in the lead payload
        appointments[:calendar_event_id] = result[:event_id]
        appointments[:calendar_event_link] = result[:event_link]
      else
        Rails.logger.error "Failed to create calendar event: #{result[:error]}"
      end
      
      appointments
    rescue => e
      Rails.logger.error "Error creating calendar event: #{e.message}"
      appointments
    end
  end
  
  def generate_brief_summary
    recent_messages = messages.last(6)
    user_interests = recent_messages.select { |m| m.sender == 'user' }.map(&:content).join(' ')
    
    summary = []
    summary << "Customer expressed interest in apartment tour"
    summary << "Conversation topics: #{determine_conversation_topics.join(', ')}" if determine_conversation_topics.any?
    
    if user_interests.length > 50
      summary << "Customer notes: #{user_interests.truncate(200)}"
    end
    
    summary.join('. ')
  end

  def messages_for_llm
    messages.map do |message|
      Langchain::Assistant::Messages::OpenAIMessage.new(
        role: message.role,
        content: message.body
      )
    end
  end
end
