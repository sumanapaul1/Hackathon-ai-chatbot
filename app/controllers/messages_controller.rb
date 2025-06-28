class MessagesController < ApplicationController
    def create
      @chat = Chat.find(params[:chat_id])
      @message = @chat.messages.create(message_params)
  
      if @message.sender == "user"
        # Generate assistant response using OpenAI
        assistant_response = generate_assistant_response(@message.content)
        @assistant_message = @chat.messages.create(content: assistant_response, sender: "assistant")
      end
  
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @chat }
      end
    end
  
    private
  
    def message_params
      params.require(:message).permit(:content, :sender)
    end
  
    def generate_assistant_response(user_message)
      client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
      response = client.chat(
        parameters: {
          model: "gpt-4",
          messages: [
            { role: "system", content: "You are a helpful assistant." },
            { role: "user", content: user_message }
          ]
        }
      )
      response.dig("choices", 0, "message", "content")
    rescue => e
      "Sorry, I couldn't process your request."
    end
  end