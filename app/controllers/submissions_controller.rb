class SubmissionsController < ApplicationController
  before_action :load_knowledge_base

  def create
    user_message = params[:content] || params.dig(:submission, :input)
    @chat = Chat.find(params[:chat_id])

    @submission = Submission.create!(chat: @chat, input: user_message)

    session[:messages] ||= []
    session[:messages] << { role: 'user', content: user_message, timestamp: Time.now }

    AssistantResponseJob.perform_later(chat: @chat, submission: @submission)
    head :ok
  end

  private

  def load_knowledge_base
    @knowledge_base = JSON.parse(File.read(Rails.root.join('knowledge_base.json')))
  rescue Errno::ENOENT
    Rails.logger.error("knowledge_base.json not found")
    @knowledge_base = []
  end

end

private

def submission_params
  params.require(:submission).permit(:input)
end
