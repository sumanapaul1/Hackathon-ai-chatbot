class ChatsController < ApplicationController
  def index
    @chats = Chat.all
  end

  def show
    @chat = Chat.find(params[:id])
    @message = Message.new
  end

  def create
    @chat = Chat.create(agent_id: Agent.last.id)
    redirect_to @chat
  end
end
