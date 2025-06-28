require 'google/apis/calendar_v3'
require 'googleauth'

class GoogleCalendarService
  include Google::Apis::CalendarV3
  
  CALENDAR_ID = ENV['GOOGLE_CALENDAR_ID'] || 'primary'
  SCOPES = [Google::Apis::CalendarV3::AUTH_CALENDAR]
  
  def initialize
    @service = CalendarService.new
    @service.authorization = authorize
  end
  
  def create_tour_appointment(appointment_details)
    return { success: false, error: "Authentication failed", message: "Google Calendar not properly configured" } unless @service.authorization
    
    return unless valid_appointment_details?(appointment_details)
    
    event = build_event(appointment_details)
    
    begin
      created_event = @service.insert_event(CALENDAR_ID, event)
      Rails.logger.info "Google Calendar event created: #{created_event.id}"
      
      {
        success: true,
        event_id: created_event.id,
        event_link: created_event.html_link,
        message: "Tour appointment scheduled successfully"
      }
    rescue Google::Apis::Error => e
      Rails.logger.error "Google Calendar API error: #{e.message}"
      Rails.logger.error "Full error details: #{e.inspect}"
      
      {
        success: false,
        error: e.message,
        message: "Failed to schedule appointment in calendar"
      }
    end
  end
  
  # Add a test method to check authentication
  def test_authentication
    Rails.logger.info "Starting authentication test..."
    
    begin
      # Test basic authentication first
      if @service.authorization.nil?
        return {
          success: false,
          error: "No authorization object",
          message: "Service authorization failed during initialization"
        }
      end
      
      Rails.logger.info "Authorization object exists, testing API call..."
      calendar_list = @service.list_calendar_lists
      
      Rails.logger.info "API call successful, found #{calendar_list.items.size} calendars"
      {
        success: true,
        message: "Authentication successful",
        calendars_count: calendar_list.items.size
      }
    rescue Google::Apis::ClientError => e
      Rails.logger.error "Google API Client Error: #{e.message}"
      Rails.logger.error "Error status: #{e.status_code}"
      Rails.logger.error "Error body: #{e.body}"
      {
        success: false,
        error: "#{e.status_code}: #{e.message}",
        message: "Client authentication error",
        details: e.body
      }
    rescue Google::Apis::AuthorizationError => e
      Rails.logger.error "Google API Authorization Error: #{e.message}"
      {
        success: false,
        error: e.message,
        message: "Authorization failed - check service account permissions",
        details: "Service account may not have calendar access"
      }
    rescue Google::Apis::Error => e
      Rails.logger.error "Google API Error: #{e.message}"
      Rails.logger.error "Error class: #{e.class}"
      {
        success: false,
        error: e.message,
        message: "API error",
        details: e.class.to_s
      }
    rescue => e
      Rails.logger.error "Unexpected error during authentication test: #{e.message}"
      Rails.logger.error "Error class: #{e.class}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(5).join('\n')}"
      {
        success: false,
        error: e.message,
        message: "Unexpected error",
        details: e.class.to_s
      }
    end
  end
  
  private
  
  def authorize
    Rails.logger.info "Attempting Google Calendar authentication..."
    
    if ENV['GOOGLE_SERVICE_ACCOUNT_JSON'].blank?
      Rails.logger.error "GOOGLE_SERVICE_ACCOUNT_JSON environment variable is not set"
      return nil
    end
    
    begin
      # Parse the JSON to validate it
      service_account_json = JSON.parse(ENV['GOOGLE_SERVICE_ACCOUNT_JSON'])
      Rails.logger.info "Service account email: #{service_account_json['client_email']}"
      
      # Service Account authorization (recommended for server-to-server)
      credentials = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: StringIO.new(ENV['GOOGLE_SERVICE_ACCOUNT_JSON']),
        scope: SCOPES
      )
      
      Rails.logger.info "Google Calendar authentication successful"
      credentials
      
    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON in GOOGLE_SERVICE_ACCOUNT_JSON: #{e.message}"
      nil
    rescue => e
      Rails.logger.error "Google Auth error: #{e.message}"
      Rails.logger.error "Error details: #{e.inspect}"
      nil
    end
  end
  
  def build_event(details)
    start_time = parse_appointment_time(details[:date], details[:time])
    end_time = start_time + 1.hour # Default 1-hour tour duration
    
    Google::Apis::CalendarV3::Event.new(
      summary: "STONE Creek Apartment Tour - #{details[:customer_name]}",
      description: build_event_description(details),
      location: "STONE Creek Apartment and Homes, 2700 Trimmier Rd, Killeen, TX 76542",
      start: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: start_time.iso8601,
        time_zone: 'America/Chicago'
      ),
      end: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: end_time.iso8601,
        time_zone: 'America/Chicago'
      ),

      reminders: Google::Apis::CalendarV3::Event::Reminders.new(
        use_default: true
      ),
      visibility: 'private',
      status: 'confirmed'
    )
  end
  
  def build_event_description(details)
    description = []
    description << "Apartment Tour Appointment"
    description << ""
    description << "Customer: #{details[:customer_name]}" if details[:customer_name]
    description << "Email: #{details[:customer_email]}" if details[:customer_email]
    description << "Phone: #{details[:customer_phone]}" if details[:customer_phone]
    description << ""
    
    if details[:interests]&.any?
      description << "Interested in: #{details[:interests].join(', ')}"
      description << ""
    end
    
    if details[:conversation_summary]
      description << "Conversation Summary:"
      description << details[:conversation_summary]
      description << ""
    end
    
    description << "Tour Type: Property viewing and information session"
    description << "Duration: Approximately 1 hour"
    description << ""
    description << "Generated automatically from STONE Creek AI Chat Assistant"
    
    description.join("\n")
  end
  

  
  def parse_appointment_time(date_str, time_str)
    begin
      parsed_date = nil
      
      # Try to parse the date string directly first
      if date_str.match?(/\d/)
        # Contains numbers, likely a real date
        begin
          # Try direct parsing for formats like "july 3", "december 23", "7/3/2025"
          parsed_date = Date.parse(date_str)
        rescue ArgumentError => e
          # Direct parsing failed, continue to special cases
        end
      end
      
      # If direct parsing failed, handle special cases
      if parsed_date.nil?
        if date_str.include?(',')
          # "Monday, December 23"
          parsed_date = Date.parse(date_str)
        elsif date_str.downcase.match?(/\b(?:january|february|march|april|may|june|july|august|september|october|november|december)\b/)
          # Contains month name but no comma - try different formats
          # Handle "july 3", "3 july", etc.
          month_day_patterns = [
            date_str,  # Original format
            date_str.split.reverse.join(' '), # Reverse if needed
            "#{date_str} #{Date.current.year}" # Add current year
          ]
          
          month_day_patterns.each do |pattern|
            begin
              parsed_date = Date.parse(pattern)
              break
            rescue ArgumentError
              next
            end
          end
        else
          # Handle day names (assuming next occurrence)
          day_name = date_str.downcase
          days = %w[sunday monday tuesday wednesday thursday friday saturday]
          target_wday = days.index(day_name)
          
          if target_wday
            today = Date.current
            days_ahead = ((target_wday - today.wday) % 7)
            days_ahead = 7 if days_ahead == 0 # Next week if it's the same day
            parsed_date = today + days_ahead.days
          end
        end
      end
      
      # Fallback to tomorrow if all parsing failed
      if parsed_date.nil?
        parsed_date = Date.current + 1.day
      end
      
      # Ensure the parsed date is in the correct year (handle year rollover)
      if parsed_date < Date.current
        parsed_date = parsed_date.next_year
      end
      
      # Parse time and combine with date
      time = Time.parse("#{time_str} #{parsed_date}")
      
      # Ensure it's in the future
      if time < Time.current
        time += 1.week
      end
      
      time
    rescue => e
      Rails.logger.error "Error parsing appointment time: #{e.message}"
      # Default to tomorrow at 2 PM
      (Date.current + 1.day).beginning_of_day + 14.hours
    end
  end
  
  def valid_appointment_details?(details)
    details.is_a?(Hash) &&
      details[:customer_email].present? &&
      details[:date].present? &&
      details[:time].present?
  end
end 