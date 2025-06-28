# Google Calendar Integration Setup

This guide will help you set up Google Calendar integration for automatic apartment tour scheduling.

## Prerequisites

1. Google Cloud Platform account
2. Google Calendar API enabled
3. Service Account credentials

## Step 1: Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable the Google Calendar API

## Step 2: Create Service Account

1. Navigate to **IAM & Admin > Service Accounts**
2. Click **Create Service Account**
3. Provide a name: `calendar-service-account`
4. Grant the role: **Editor** (or create custom role with calendar access)
5. Click **Done**

## Step 3: Generate Service Account Key

1. Click on the created service account
2. Go to **Keys** tab
3. Click **Add Key > Create New Key**
4. Select **JSON** format
5. Download the JSON file

## Step 4: Configure Environment Variables

Add these variables to your `.env` file:

```bash
# Google Calendar Integration
GOOGLE_SERVICE_ACCOUNT_JSON={"type":"service_account","project_id":"your-project-id","private_key_id":"...","private_key":"-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n","client_email":"...","client_id":"...","auth_uri":"https://accounts.google.com/o/oauth2/auth","token_uri":"https://oauth2.googleapis.com/token","auth_provider_x509_cert_url":"https://www.googleapis.com/oauth2/v1/certs","client_x509_cert_url":"..."}

# Calendar ID (use 'primary' for main calendar or specific calendar ID)
GOOGLE_CALENDAR_ID=primary

# Property manager email (will be added as attendee)
PROPERTY_MANAGER_EMAIL=manager@stonecreekapartments.com
```

## Step 5: Share Calendar with Service Account

1. Open Google Calendar
2. Go to **Settings** for your target calendar
3. Under **Share with specific people**, add the service account email
4. Grant **Make changes to events** permission

## Step 6: Test the Integration

The system will automatically:

1. **Extract appointment details** from chat conversations
2. **Create calendar events** when appointments are confirmed
3. **Include customer details** in event description
4. **Set default reminders** for the property manager

## Event Details

Each calendar event will include:

- **Title**: "STONE Creek Apartment Tour - [Customer Name]"
- **Location**: "STONE Creek Apartment and Homes, 2700 Trimmier Rd, Killeen, TX 76542"
- **Duration**: 1 hour
- **Description**: Customer details, interests, conversation summary
- **Reminders**: Default calendar reminders

## Troubleshooting

### Common Issues:

1. **Authentication Errors**
   - Verify service account JSON is correctly formatted
   - Ensure Calendar API is enabled in Google Cloud Console

2. **Calendar Not Found**
   - Check GOOGLE_CALENDAR_ID is correct
   - Verify service account has access to the calendar

3. **Permission Denied**
   - Ensure service account email is shared with calendar
   - Check service account has proper IAM roles

### Testing Manually

You can test the service in Rails console:

```ruby
# In Rails console
service = GoogleCalendarService.new
result = service.create_tour_appointment({
  customer_name: "Test Customer",
  customer_email: "santosh.yarrasuri@gmail.com",
  customer_phone: "555-1234",
  date: "Monday",
  time: "2:00 PM",
  interests: ["1BHK", "Swimming Pool"],
  conversation_summary: "Customer interested in apartment tour"
})

puts result
```

## Security Notes

- Never commit the service account JSON to version control
- Use environment variables for all sensitive credentials
- Regularly rotate service account keys
- Monitor calendar API usage in Google Cloud Console

## Integration Flow

1. **Chat Completion**: When a chat closes with confirmed appointment
2. **Data Extraction**: System extracts date, time, customer details
3. **Event Creation**: Google Calendar event is created automatically
4. **Notifications**: Customer receives calendar invitation
5. **Lead Storage**: Calendar event ID stored in lead data

This provides a seamless experience where confirmed appointments automatically appear in Google Calendar with all relevant customer information. 