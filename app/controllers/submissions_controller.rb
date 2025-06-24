class SubmissionsController < ApplicationController
  before_action :load_knowledge_base

  def create
    user_message = params[:content] || params.dig(:submission, :input)
    session[:messages] ||= []
    session[:messages] << { role: 'user', content: user_message, timestamp: Time.now }
    bot_response = generate_bot_response(user_message)
    session[:messages] << { role: 'bot', content: bot_response, timestamp: Time.now }
    render json: { messages: session[:messages].last(2) }
  end

  private

  def load_knowledge_base
    @knowledge_base = JSON.parse(File.read(Rails.root.join('knowledge_base.json')))
  rescue Errno::ENOENT
    Rails.logger.error("knowledge_base.json not found")
    @knowledge_base = []
  end

  def generate_bot_response(query)
    query = query.to_s.downcase.strip
    property = @knowledge_base["properties"][0] || {}
    if query.include?('floorplan') || query.include?('1bhk') || query.include?('2bhk')
      floorplans = property['floorplans'].to_a.select do |plan|
        plan['rooms'].any? { |room| query.include?(room['type'].downcase) }
      end
      return floorplans.map { |plan| "- #{plan['rooms'][0]['type']} (#{plan['class']}): #{plan['rooms'][0]['size']}, #{plan['rooms'][0]['price']}." }.join("\n").presence || "No matching floor plans."
    elsif query.include?('amenities')
      return "STONE Creek offers: #{property['']['amenities'].join(', ')}."
    else
      return "Sorry, I didn’t understand. Ask about floor plans, vacancies, amenities, or tours!"
    end
  end
end
