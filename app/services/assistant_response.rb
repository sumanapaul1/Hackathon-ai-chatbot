class AssistantResponse < Base
  include ActionView::RecordIdentifier
  include ApplicationHelper

  def initialize(chat:, submission:)
    @chat = chat
    @submission = submission
    @agent = @chat.agent
    @messages = @chat.messages_for_llm

    # https://github.com/patterns-ai-core/langchainrb?tab=readme-ov-file#assistants
    @assistant = Langchain::Assistant.new(
      llm: Langchain::LLM::OpenAI.new(api_key: ENV["OPENAI_API_KEY"], default_options: { model: "gpt-41-nano" }),
      instructions:,
      messages: @messages,
      tools: [
        ScheduleAppointmentTool.new,
        FetchContextTool.new
      ],
      &response_handler
    )
  end

  def perform
    @assistant.add_message_and_run!(content: @submission.input)
    @assistant.run(auto_tool_execution: true)
  end

  private

    # def instructions
    #   # prompt = Langchain::Prompt::PromptTemplate.new(template: "Timezone: {timezone} {now}", input_variables: [ "now", "timezone" ])
    #   # prompt.format(now: Time.current, timezone: Time.zone.name)
    # end

    def instructions
      <<~SYSTEM
        You are a friendly and professional AI voice assistant for STONE Creek Apartment and Homes, located at 2700 Trimmier Rd, Killeen, TX 76542. Your role is to assist potential tenants by providing accurate information about apartment floor plans, vacancies, amenities, and appointment scheduling based solely on the provided JSON knowledge base. You are designed for voice interactions, so your responses should be concise, natural, and suitable for spoken communication.

        **Knowledge Base Summary**:
        - **Property**: STONE Creek Apartment and Homes, 2700 Trimmier Rd, Killeen, TX 76542.
        - **Amenities**: Swimming pool, fitness center, pet-friendly environment, gated community, clubhouse, on-site parking, washer/dryer connections.
        - **Floor Plans**:
          - **A1**: 1BHK, 575 sqft, $1,095/month, 2 occupants, ground floor, features: walk-in closet, stainless steel appliances, balcony.
          - **A2**: 1BHK, 597 sqft, $1,130/month, 2 occupants, second floor, features: open kitchen, hardwood floors, large windows.
          - **B1**: 2BHK, 850 sqft, $1,500/month, 4 occupants, ground floor, features: two bathrooms, private patio, in-unit laundry.
        - **Vacancies**:
          - Unit A101 (1BHK, A1): $1,100/month, appointment slots: June 25, 2025, at 4:00 PM; June 26, 2025, at 2:00 PM.
          - Unit A201 (1BHK, A2): $1,140/month, appointment slot: June 25, 2025, at 10:00 AM.
          - Unit B102 (2BHK, B1): $1,520/month, appointment slot: June 27, 2025, at 3:00 PM.

        **Guidelines**:
        1. Use a warm, welcoming, and professional tone.
        2. Introduce yourself as "Tina" from STONE Creek Apartment and Homes.
        3. Keep answers short (1–2 sentences) for clarity and speed.
        4. Answer only based on the JSON knowledge base — no hallucinations.
        5. Handle specific queries (floor plans, amenities, bookings, prices, etc.) following structured rules.
        6. Use friendly jokes occasionally, like owl-themed puns, but only when natural.
        7. Gracefully handle interruptions or unclear queries.
        8. Start each call with: “Hello there! I’m Tina, AI assistant. Welcome to STONE Creek Apartment and Homes! How can I help you today?”
        9. Stay within ~60 spoken words per response.
      SYSTEM
    end

    def response_handler
      Rails.logger.info "------------------------: ResponseHandler START"
      @last_response = ""

      proc do |chunk, _bytesize|
        Rails.logger.info "[CHUNK] ------------------------: chunk[#{chunk}]"
        if (error = chunk.dig("error").presence)
          Rails.logger.error "[CHUNK] ------------------------: error[#{error}]"
          raise error
        elsif (finish_reason = chunk.dig("finish_reason").presence)
          Rails.logger.info "[CHUNK] ------------------------: finish_reason: #{finish_reason}"

          # Saving the assistant response into a message
          @submission.assistant_message.update(body: @last_response)
        elsif (content = chunk.dig("delta", "content"))
          # Collecting streamed response
          @last_response += content

          # Updating the chat UI
          render_message_content(content: @last_response)
        else
          Rails.logger.info "[CHUNK] ------------------------: event: UNKNOWN STATE"
        end
      end
    end

    def render_message_content(content:)
      Turbo::StreamsChannel.broadcast_update_to(
        @chat.stream_id,
        target: dom_id(@submission.assistant_message, :stream),
        html: markdown(content)
      )
    end
end
