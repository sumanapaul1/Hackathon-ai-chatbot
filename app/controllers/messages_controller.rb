class MessagesController < ApplicationController
      def create
    @chat = Chat.find(params[:chat_id])
    @message = @chat.messages.create(message_params)

    if @message.sender == "user"
      # Check if user is confirming they want to close the chat
      user_confirming_closure = user_confirming_chat_closure?(@message, @chat)
      
      if user_confirming_closure
        auto_close_chat_with_message(@chat)
        @auto_closed = true
      else
        # Check if user's message indicates conversation completion
        should_close = should_auto_close_chat_from_user_message?(@message, @chat)
        
        if should_close
          # Ask for confirmation instead of immediately closing
          confirmation_response = ask_for_closure_confirmation(@chat)
          @assistant_message = @chat.messages.create(content: confirmation_response, sender: "assistant")
        else
          # Generate normal assistant response using OpenAI
          assistant_response = generate_assistant_response(@message.content, @chat.agent)
          @assistant_message = @chat.messages.create(content: assistant_response, sender: "assistant")
        end
      end
    end

    respond_to do |format|
      if @auto_closed
        format.turbo_stream { render 'chats/auto_close' }
      else
        format.turbo_stream
      end
      format.html { redirect_to @chat }
    end
  end
  
    private
  
    def message_params
      params.require(:message).permit(:content, :sender)
    end
  
    def generate_assistant_response(user_message, agent)
      # Build conversation history for context
      conversation_messages = build_conversation_messages(@chat, agent)
      conversation_messages << { role: "user", content: user_message }

      client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
      response = client.chat(
        parameters: {
          model: agent.model || "gpt-4",
          messages: conversation_messages
        }
      )
      response.dig("choices", 0, "message", "content")
    rescue => e
      "Sorry, I couldn't process your request."
    end

    def build_conversation_messages(chat, agent)
      messages = []
      
      # Add system prompt with knowledge base
      system_content = build_system_prompt(agent)
      messages << { role: "system", content: system_content }
      
      # Add recent conversation history (last 10 messages for context)
      recent_messages = chat.messages.order(:created_at).last(10)
      recent_messages.each do |msg|
        role = msg.sender == "user" ? "user" : "assistant"
        messages << { role: role, content: msg.content }
      end
      
      messages
    end

    def build_system_prompt(agent)
      base_prompt = agent.system_prompt.present? ? agent.system_prompt : "You are a helpful assistant."
      
      # Add knowledge base if it exists
      knowledge_base = load_knowledge_base
      base_prompt += "\n\n## Knowledge Base:\n#{knowledge_base}"
      base_prompt += "\n\nUse this knowledge base to answer questions when relevant. If the information is not in the knowledge base, you can use your general knowledge but mention when you're going beyond the provided knowledge base."
      
      base_prompt
    end

    def load_knowledge_base
      # Generate dynamic appointment slots for the next 7 days
      weekly_slots = generate_weekly_appointment_slots
      
      <<~SYSTEM
       You are a friendly and professional AI voice assistant for STONE Creek Apartment and Homes, located at 2700 Trimmier Rd, Killeen, TX 76542. Your role is to assist potential tenants by providing accurate information about apartment floor plans, vacancies, amenities, and appointment scheduling based solely on the provided knowledge base. You are designed for voice interactions, so your responses should be concise, natural, and suitable for spoken communication.

        **IMPORTANT CONVERSATION FLOW**:
        1. **Always ask for the user's name first** after greeting
        2. **Use their name throughout the conversation** to personalize the experience
        3. **Systematically collect contact information** (name, phone, email) during the conversation
        4. **Ask for email specifically** when scheduling appointments or providing detailed information
        5. **Confirm all collected information** before completing any booking

        **Knowledge Base Summary**:
        - **Property**: STONE Creek Apartment and Homes, 2700 Trimmier Rd, Killeen, TX 76542.
        - **Amenities**: Swimming pool, fitness center, pet-friendly environment, gated community, clubhouse, on-site parking, washer/dryer connections.
        - **Floor Plans**:
          - **A1**: 1BHK, 575 sqft, $1,095/month, 2 occupants, ground floor, features: walk-in closet, stainless steel appliances, balcony.
          - **A2**: 1BHK, 597 sqft, $1,130/month, 2 occupants, second floor, features: open kitchen, hardwood floors, large windows.
          - **B1**: 2BHK, 850 sqft, $1,500/month, 4 occupants, ground floor, features: two bathrooms, private patio, in-unit laundry.
        - **Current Date**: #{Date.current.strftime("%B %d, %Y (%A)")}
        - **Weekly Appointment Schedule** (Next 7 Days):
          #{format_weekly_schedule(weekly_slots)}

        **Guidelines**:
        1. **Tone and Style**: Use a warm, welcoming, and professional tone, like a helpful leasing agent. Keep responses short (1-2 sentences when possible) for voice clarity.
        2. **Name Collection**: ALWAYS ask "What's your name?" or "May I have your name?" early in the conversation
        3. **Use Name**: Once you have their name, use it frequently: "Great question, [Name]!", "Let me help you with that, [Name]"
        4. **Contact Collection Strategy**:
           - **Name**: Ask first, right after greeting
           - **Phone**: Ask when scheduling appointments: "What's the best phone number to reach you, [Name]?"
           - **Email**: Ask when providing detailed info or confirming appointments: "What's your email address so I can send you the details, [Name]?"
        5. **Information Flow**: 
           - Start with name collection
           - Answer their questions about properties
           - When interest is shown, collect phone and email
           - Schedule appointments with full contact information
        6. **Query Handling**:
          - **Floor Plans**: For queries about floor plans (e.g., "What 1BHK apartments are available?"), mention the class (A1, A2, B1), type (1BHK, 2BHK), size, price, occupancy, level, and key features (limit to 3 features for brevity).
          - **Vacancies**: For queries about availability (e.g., "What units are available?"), provide unit number, type, class, price, and available appointment slots.
          - **Amenities**: For queries about amenities (e.g., "What amenities do you offer?"), list up to 5 amenities and offer to provide more details if asked.
          - **Bookings**: For booking requests, collect ALL contact information (name, phone, email) before confirming. Always confirm the unit and slot if available.
          - **Specific Units**: If a unit (e.g., "A101") is mentioned, provide its details (type, class, price, available slots).
          - **Price Queries**: If asked about units under a price (e.g., "Units under $1,200"), filter vacancies by price and list matches with available slots.
          - **Weekly Scheduling**: When users ask about availability for the week, this week, specific days (Monday, Tuesday, etc.), or date ranges, reference the weekly schedule provided.
          - **Flexible Scheduling**: Offer multiple options across the week and ask for user preferences on day/time.
        7. **Contact Information Collection Examples**:
           - "Hi! I'm Tina, your AI assistant. Welcome to STONE Creek! What's your name?"
           - "Thanks, [Name]! How can I help you today?"
           - "That's a great question, [Name]. Before I provide more details, what's the best phone number to reach you?"
           - "Perfect, [Name]! I'd love to send you some information. What's your email address?"
           - "Excellent, [Name]! So I have your name as [Name], phone as [phone], and email as [email]. Is that correct?"
        8. **Unclear Queries**: If the query is unclear or not covered by the knowledge base, respond politely: "I'm sorry, [Name], I don't have that information. Can I help with floor plans, vacancies, amenities, or tours?"
        9. **Interruptions**: If interrupted (e.g., detected by speech activity), stop speaking immediately and process the new query.
        10. **Engagement**: Occasionally include a light, professional dad joke or owl-themed joke to keep the conversation engaging, but only when appropriate (e.g., after a successful query response). Examples:
          - "Why did the owl move in? It wanted a 'hoot' of a deal!"
          - "Why did the apartment go to therapy? It had too many 'deep-rooted' issues!"
        11. **Voice Interaction**: Avoid complex terms or long lists in responses. Use conversational phrases like "We have a lovely 1BHK A1 unit" or "Let me check that for you."
        12. **Fallback**: If audio transcription fails, respond: "Sorry, I didn't catch that. Could you repeat it?"

        **Example Conversation Flow**:
        - **AI**: "Hello! I'm Tina, your AI assistant. Welcome to STONE Creek Apartment and Homes! What's your name?"
        - **User**: "Hi, I'm John"
        - **AI**: "Nice to meet you, John! How can I help you today?"
        - **User**: "I'm looking for a 1-bedroom apartment"
        - **AI**: "Great choice, John! We have two 1BHK options: the A1 at $1,095/month with a balcony, and the A2 at $1,130/month with hardwood floors. Which interests you more?"
        - **User**: "The A1 sounds good"
        - **AI**: "Excellent choice, John! The A1 has a walk-in closet and stainless steel appliances too. Would you like to schedule a tour? What's the best phone number to reach you?"
        - **User**: "Sure, it's 555-1234"
        - **AI**: "Perfect, John! I have several slots available this week. Would Monday at 2 PM or Tuesday at 11 AM work better for you?"
        - **User**: "Monday at 2 PM works"
        - **AI**: "Wonderful, John! What's your email address so I can send you the confirmation details?"
        - **User**: "john@email.com"
        - **AI**: "Perfect! Your tour is confirmed for Monday at 2 PM. I have your contact as John, 555-1234, john@email.com. Thank you for choosing STONE Creek!"

        **Conversation Completion & Auto-Close**:
        When any of these conditions are met, the conversation should naturally conclude with a closing statement:
        1. **Appointment Confirmed**: After user explicitly confirms a specific appointment slot
        2. **Lead Information Collected**: After gathering name, phone number, and email with user confirmation
        3. **User Indicates Completion**: When user says goodbye, thanks, or indicates they're done
        4. **Information Fully Provided**: After answering all user questions and user confirms satisfaction
        
        **Important Flow Guidelines**:
        - When providing available appointment slots, DO NOT use completion language
        - Only use completion language AFTER user has selected and confirmed a specific slot
        - Wait for explicit user confirmation before considering conversation complete
        - Use phrases like "Which time works best for you?" when offering options
        - Reserve completion language for when booking is actually confirmed
        
        **Offering Slots (Do NOT close)**: 
        - "I have availability on Monday at 10 AM and 2 PM, Tuesday at 11 AM and 3 PM. Which time works best for you?"
        - "Great! For tomorrow I have slots at 10:00 AM and 3:30 PM available. Would either of these work?"
        
        **Confirming Appointment (OK to close)**: 
        - "Perfect! Your appointment is confirmed for Monday at 2 PM. Thank you for choosing STONE Creek!"
        - "Excellent! I've booked your tour for Tuesday at 11 AM. See you then!"
        
        **Closing Statements**: Use phrases like:
        - "Perfect! I have all the information I need. Thank you for your interest in STONE Creek!"
        - "Great! Your appointment is confirmed. Thanks for choosing STONE Creek Apartment and Homes!"
        - "Thank you for your time today. Have a wonderful day and we look forward to seeing you!"
        - "I'm glad I could help with all your questions. Thank you and goodbye!"

        **Constraints**:
        - Use only the provided weekly appointment schedule - do not create additional time slots.
        - Keep responses under 30 seconds when spoken (about 50-60 words).
        - Handle interruptions gracefully by stopping and addressing the new query.
        - Always reference specific days with dates when possible (e.g., "Monday, #{Date.current.next_occurring(:monday).strftime("%B %d")}").
        - Office closed on weekends - redirect weekend requests to weekday alternatives.
        - ALWAYS collect name, phone, and email before confirming any appointments.
      SYSTEM
    end

    def generate_weekly_appointment_slots
      weekly_schedule = {}
      
      # Generate slots for the next 7 days
      (0..6).each do |days_ahead|
        date = Date.current + days_ahead
        slots = generate_appointment_slots_for_date(date)
        
        unless slots.empty?
          day_name = date.strftime("%A")
          date_string = date.strftime("%B %d")
          weekly_schedule[date] = {
            day_name: day_name,
            date_string: date_string,
            slots: slots
          }
        end
      end
      
      weekly_schedule
    end

    def generate_appointment_slots_for_date(date)
      # Generate realistic appointment slots for leasing office hours (9 AM - 6 PM)
      morning_slots = ["9:00 AM", "10:00 AM", "11:30 AM"]
      afternoon_slots = ["1:00 PM", "2:30 PM", "3:30 PM", "5:00 PM"]
      
      # Skip weekend appointments (assuming office closed on weekends)
      # wday: 0 = Sunday, 6 = Saturday
      return [] if date.wday == 0 || date.wday == 6
      
      # Generate varied availability (2-4 slots per day)
      all_slots = morning_slots + afternoon_slots
      available_count = [2, 3, 4].sample
      
      all_slots.sample(available_count).sort_by { |time| Time.parse(time) }
    end

    def format_weekly_schedule(weekly_slots)
      schedule_lines = []
      
      weekly_slots.each do |date, day_info|
        day_display = "#{day_info[:day_name]}, #{day_info[:date_string]}"
        slots_display = day_info[:slots].join(", ")
        
        schedule_lines << "**#{day_display}**: #{slots_display}"
      end
      
      if schedule_lines.empty?
        "No appointments available this week (weekends excluded). Please call for special scheduling."
      else
        schedule_lines.join("\n          ")
      end
    end

    def get_sample_day_slots(day_name)
      # Helper method for examples - returns sample slots
      sample_slots = ["10:00 AM", "2:30 PM", "3:30 PM"]
      sample_slots.sample(2).join(" and ")
    end

    def get_afternoon_slots_for_tomorrow
      # Helper method for examples - returns sample afternoon slots
      ["1:00 PM", "2:30 PM", "3:30 PM"].sample(2).join(" and ")
    end

    def format_appointment_slots(unit, today_slots, tomorrow_slots)
      # This method can be removed as we're now using weekly scheduling
      # Keeping for backward compatibility if needed
      slots = []
      
      unless today_slots.empty?
        today_formatted = "Today (#{Date.current.strftime("%B %d")}): #{today_slots.join(", ")}"
        slots << today_formatted
      end
      
      unless tomorrow_slots.empty?
        tomorrow_formatted = "Tomorrow (#{Date.tomorrow.strftime("%B %d")}): #{tomorrow_slots.join(", ")}"
        slots << tomorrow_formatted
      end
      
      if slots.empty?
        "No appointments available today or tomorrow. Please call for scheduling."
      else
        "Available appointment slots:\n            - #{slots.join("\n            - ")}"
      end
    end

    def should_auto_close_chat_from_user_message?(user_message, chat)
      message_content = user_message.content.downcase.strip
      
      # Simple, direct patterns that should definitely trigger closure confirmation
      goodbye_patterns = [
        # Simple goodbyes
        "goodbye", "bye", "bye!", "goodbye!", 
        "thank you bye", "thanks bye", "thank you goodbye", "thanks goodbye",
        
        # Completion signals
        "that's all", "i'm done", "i'm good", "all done", "that's it",
        "all set", "i'm all set", "we're done", "that's perfect",
        
        # Polite endings
        "have a great day", "talk to you later", "see you later", 
        "have a good day", "take care",
        
        # Strong completion
        "thank you for your help", "thanks for your help", 
        "thank you for everything", "thanks for everything",
        "that's exactly what i needed", "that's all i needed",
        "that answers everything", "that helps a lot"
      ]
      
      # Check for exact matches first (most reliable)
      return true if goodbye_patterns.include?(message_content)
      
      # Check for partial matches
      return true if message_content.match?(/^(?:goodbye|bye)\.?\s*$/i)
      return true if message_content.match?(/^(?:that's all|i'm done|i'm good|all done)\.?\s*$/i)
      return true if message_content.match?(/thank you.*(?:bye|goodbye|that's all)$/i)
      return true if message_content.match?(/(?:goodbye|bye).*thank you$/i)
      
      # Contact info provided
      return true if message_content.match?(/(?:my phone|phone number|call me at).*\d{3}[-.]?\d{3}[-.]?\d{4}/)
      return true if message_content.match?(/(?:my email|email is|email:|@).*[a-z0-9.-]+@[a-z0-9.-]+\.[a-z]+/)
      
      # Check appointment confirmation flow
      user_confirmed_appointment_or_info?(user_message, chat)
    end

    def user_confirmed_appointment_or_info?(user_message, chat)
      user_content = user_message.content.downcase
      
      # Get the last assistant message to see what was offered
      last_assistant_msg = chat.messages.where(sender: 'assistant').last
      return false unless last_assistant_msg
      
      assistant_content = last_assistant_msg.content.downcase
      
      # User gives simple confirmation (yes, ok, sure, etc.)
      user_confirmed = user_content.match?(/^(?:yes|ok|okay|sure|perfect|great|sounds good|that works|works for me)\.?\s*$/i)
      
      # ONLY close if assistant has CONFIRMED/COMPLETED a booking, not just offered slots
      # Look for completion language from AI, not just offering slots
      assistant_confirmed_booking = assistant_content.match?(/(?:confirmed|booked|scheduled|appointment is set).*(?:appointment|tour)|(?:perfect|excellent).*(?:appointment|tour).*(?:confirmed|booked|scheduled)/)
      
      # NEVER close if assistant is asking for contact info - that's the middle of the process
      assistant_asking_contact = assistant_content.match?(/(?:what's|what is|could you provide|please provide|may i have).*(?:email|phone|contact|number)/)
      
      # NEVER close if assistant is offering appointment slots - user might be saying yes to wanting to schedule
      assistant_offering_slots = assistant_content.match?(/(?:available|slots|appointment times|would.*work|which.*works|when would)/)
      
      # Only close in very specific cases where conversation is truly complete
      return false if assistant_asking_contact || assistant_offering_slots
      
      # Only close if user confirmed AND assistant previously confirmed a completed booking
      user_confirmed && assistant_confirmed_booking
    end



    def user_confirming_chat_closure?(user_message, chat)
      message_content = user_message.content.downcase.strip
      
      # Get the last assistant message to check if it was asking for closure confirmation
      last_assistant_msg = chat.messages.where(sender: 'assistant').last
      return false unless last_assistant_msg
      
      assistant_content = last_assistant_msg.content.downcase
      
      # Check if the assistant asked for closure confirmation - be more flexible
      assistant_asked_to_close = assistant_content.include?("would you like me to close") || 
                                assistant_content.include?("is there anything else") ||
                                assistant_content.include?("shall we end our conversation") ||
                                assistant_content.include?("end our conversation") ||
                                assistant_content.include?("anything else i can help") ||
                                assistant_content.include?("are you all set")
      
      # User confirmation patterns for closing - use simple string matching
      closure_confirmations = [
        "yes", "yep", "yeah", "ok", "okay", "sure", "yes!", "ok!", "sure!",
        "yes please", "yes that's all", "yes close it", "close it", "yes, close it",
        "no", "nope", "no thanks", "that's all", "i'm done", "we're done", "done",
        "close", "close it", "end chat", "finish", "finished",
        "thank you", "thanks", "thanks!", "thank you!"
      ]
      
      user_wants_closure = closure_confirmations.include?(message_content)
      
      assistant_asked_to_close && user_wants_closure
    end

    def ask_for_closure_confirmation(chat)
      # Extract lead information to personalize the message
      extracted_info = chat.extract_lead_information
      name = extracted_info[:contact_info][:name]
      name_part = name ? "#{name}, " : ""
      
      # Check what was accomplished in the conversation
      appointment_scheduled = extracted_info[:appointments][:status] == 'confirmed'
      contact_collected = extracted_info[:contact_info][:email] || extracted_info[:contact_info][:phone]
      
      if appointment_scheduled
        confirmation_msg = "Perfect! #{name_part}I believe I have all the information needed and your appointment is scheduled. Is there anything else I can help you with today, or would you like me to close this chat?"
      elsif contact_collected
        confirmation_msg = "Great! #{name_part}I have your contact information and I've answered your questions about our apartments. Is there anything else I can help you with, or shall we end our conversation here?"
      else
        confirmation_msg = "Thank you for your questions, #{name_part}I hope I've been helpful! Is there anything else you'd like to know about STONE Creek Apartment and Homes, or are you all set?"
      end
      
      confirmation_msg
    end

    def auto_close_chat_with_message(chat)
      # Add a final message from the AI before closing
      closing_message = "This conversation has been completed. Thank you for your interest in STONE Creek Apartment and Homes! The chat will now be closed automatically."
      
      chat.messages.create(
        content: closing_message,
        sender: "assistant"
      )
      
      # Create lead from conversation before closing
      begin
        lead = chat.create_lead_from_conversation
        Rails.logger.info "Lead ##{lead.id} created from auto-closed chat ##{chat.id}"
      rescue => e
        Rails.logger.error "Failed to create lead from chat ##{chat.id}: #{e.message}"
      end
      
      # Close the chat
      chat.close!
      
      # Log the auto-close action
      Rails.logger.info "Chat ##{chat.id} was automatically closed after completion"
    end
  end