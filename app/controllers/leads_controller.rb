class LeadsController < ApplicationController
    before_action :set_lead, only: [:show]
    def index
        @leads = Lead.all
    end
    
    def new
      @lead = Lead.new
    end

    def create
        @lead = Lead.new(lead_params)

        if @lead.save
        redirect_to root_path, notice: 'Lead was successfully created.'
        else
        render :new
        end
    end

    def show
    end

    private

    def set_lead
        @lead = Lead.find(params[:id])
    end

    def lead_params
        params.require(:lead).permit(:email, payload: [:name, :phone, :message, :preferred_date])
    end
end