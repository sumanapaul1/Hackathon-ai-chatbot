class LeadsController < ApplicationController
    before_action :set_lead, only: [:show]
    
    # Skip CSRF protection for API requests (voice assistant integration)
    protect_from_forgery except: [:create]
    def index
        @leads = Lead.includes(:chat).order(created_at: :desc)
        
        # Apply filters if present
        @leads = @leads.with_email if params[:with_email] == 'true'
        @leads = @leads.hot_leads if params[:hot_leads] == 'true'
        @leads = @leads.high_score if params[:high_score] == 'true'
        @leads = @leads.with_appointments if params[:with_appointments] == 'true'
        @leads = @leads.voice_calls if params[:voice_calls] == 'true'
        @leads = @leads.chat_leads if params[:chat_leads] == 'true'
        
        # Statistics for dashboard
        @stats = {
          total_leads: Lead.count,
          voice_calls: Lead.voice_calls.count,
          chat_leads: Lead.chat_leads.count,
          with_email: Lead.with_email.count,
          hot_leads: Lead.hot_leads.count,
          high_score: Lead.high_score.count,
          with_appointments: Lead.with_appointments.count,
          avg_lead_score: Lead.average("(payload->>'lead_score')::integer").to_f.round(1)
        }
    end
    
    def new
      @lead = Lead.new
    end

    def create
        @lead = Lead.new(lead_params)
        
        # For API requests (like voice assistant), return JSON response
        if request.format.json?
          if @lead.save
            render json: { 
              status: 'success', 
              lead_id: @lead.id, 
              message: 'Lead created successfully' 
            }, status: :created
          else
            render json: { 
              status: 'error', 
              errors: @lead.errors.full_messages 
            }, status: :unprocessable_entity
          end
        else
          # For web form submissions
          if @lead.save
            redirect_to root_path, notice: 'Lead was successfully created.'
          else
            render :new
          end
        end
    end

    def show
        @conversation_summary = @lead.payload['conversation_summary'] if @lead.payload
        @contact_info = @lead.payload['contact_info'] if @lead.payload
        @chat_messages = @lead.chat.messages.order(:created_at) if @lead.chat
    end

    private

    def set_lead
        @lead = Lead.find(params[:id])
    end

    def lead_params
        params.require(:lead).permit(:email, :chat_id, payload: {})
    end
end