class ChatsController < ApplicationController
  before_action :set_chat, only: [:show, :close]
  before_action :ensure_chat_open, only: [:show]

  def index
    @chats = Chat.open.order(created_at: :desc)
  end

  def show
    @message = Message.new
    
    # Ensure the chat has a greeting message (for existing chats)
    ensure_greeting_message(@chat)
  end

  def create
    @chat = Chat.create(agent_id: Agent.last.id)
    
    # Create an automatic greeting message from the AI
    create_greeting_message(@chat)
    
    redirect_to @chat
  end

  def close
    # Create lead from conversation before closing
    begin
      lead = @chat.create_lead_from_conversation
      Rails.logger.info "Lead ##{lead.id} created from manually closed chat ##{@chat.id}"
      flash_message = 'Chat has been closed successfully and lead has been created.'
    rescue => e
      Rails.logger.error "Failed to create lead from chat ##{@chat.id}: #{e.message}"
      flash_message = 'Chat has been closed successfully.'
    end
    
    @chat.close!
    
    respond_to do |format|
      # For customer-facing interface, show closed state instead of redirecting
      format.html { redirect_to @chat, notice: flash_message }
      format.turbo_stream { render :close }
    end
  end

  private

  def set_chat
    @chat = Chat.find(params[:id])
  end

  def ensure_chat_open
    # Allow viewing closed chats for customer-friendly experience
    # The view will handle showing appropriate state for closed chats
  end

  def create_greeting_message(chat)
    greeting_content = "Hello there! I'm Tina, your AI assistant. Welcome to STONE Creek Apartment and Homes! I'm here to help you with information about our floor plans, available units, amenities, and to schedule tours. How can I assist you today?"
    
    chat.messages.create(
      content: greeting_content,
      sender: "assistant"
    )
  end

  def ensure_greeting_message(chat)
    # Check if chat has any messages, if not or if first message is not from assistant, add greeting
    if chat.messages.empty? || chat.messages.first.sender != "assistant"
      create_greeting_message(chat)
    end
  end
end
