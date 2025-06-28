# 🏠  Apartment AI Assistant

An intelligent omnichannel lead management system, featuring AI-powered voice calls and web chat with automated lead scoring and appointment scheduling.

![Ruby on Rails](https://img.shields.io/badge/Ruby_on_Rails-8.0-CC0000?style=for-the-badge&logo=ruby-on-rails&logoColor=white)
![AI Assistant](https://img.shields.io/badge/AI-Assistant-00D4AA?style=for-the-badge&logo=openai&logoColor=white)
![Lead Management](https://img.shields.io/badge/Lead-Management-FF6B6B?style=for-the-badge&logo=salesforce&logoColor=white)

## 🎯 Project Overview

This Rails application powers an intelligent customer service system that automatically captures and scores leads from multiple channels:

- **📞 AI Voice Assistant**: Handles incoming calls with natural language processing
- **💬 Web Chat Interface**: Real-time chat with visitors on your website
- **🎯 Smart Lead Scoring**: Automatically evaluates lead quality based on interaction data
- **📊 Unified Dashboard**: Manage all leads from voice calls and chat in one place
- **📅 Appointment Scheduling**: Automated booking with Google Calendar integration

## ✨ Key Features

### 🔊 Voice Integration
- **AI-Powered Voice Assistant** using OpenAI and Twilio
- **Real-time Transcription** with confidence scoring
- **Automatic Lead Creation** from voice conversations
- **Intent Detection** for apartment inquiries and tour requests

### 💬 Web Chat System
- **Real-time Chat Interface** with Turbo Streams
- **Auto-close Detection** with user confirmation
- **Message History** with conversation context
- **Lead Capture** from chat interactions

### 🎯 Advanced Lead Management
- **Intelligent Lead Scoring** (0-100 points)
  - Email: +30 points
  - Phone: +25 points
  - Name: +15 points
  - Appointment Request: +20 points
  - Interests: +10 points
  - High Engagement: +10 points

- **Source Differentiation**
  - 📞 Voice Call Leads (Purple badges)
  - 💬 Web Chat Leads (Blue badges)

- **Lead Classification**
  - 🔥 Hot Leads (80+ score)
  - 🌡️ Warm Leads (60-79 score)
  - ❄️ Cold Leads (<60 score)

### 📊 Analytics Dashboard
- **Real-time Statistics** showing total leads by source
- **Advanced Filtering** by source, score, email, appointments
- **Lead Quality Metrics** with visual indicators
- **Conversion Tracking** across channels

### 📅 Smart Scheduling
- **Google Calendar Integration** for automatic appointment booking
- **Date/Time Extraction** from natural language
- **Calendar Event Creation** with customer details
- **Appointment Status Tracking**

## 🛠️ Tech Stack

- **Backend**: Ruby on Rails 8.0
- **Database**: PostgreSQL
- **Real-time**: Turbo Streams, Action Cable
- **Styling**: Tailwind CSS
- **AI Integration**: OpenAI API
- **Voice**: Twilio Voice API
- **Calendar**: Google Calendar API
- **Lead Storage**: JSONB for flexible data structures

## 🚀 Quick Start

### Prerequisites

- Ruby 3.3.7
- Rails 8.0
- PostgreSQL
- Redis (for Action Cable)
- Twilio Account
- OpenAI API Key
- Google Calendar API credentials

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd Hackathon-ai-chatbot
   ```

2. **Install dependencies**
   ```bash
   bundle install
   ```

3. **Setup database**
   ```bash
   rails db:create
   rails db:migrate
   ```

4. **Configure environment variables**
   ```bash
   # Create .env file with:
   OPENAI_API_KEY=your_openai_api_key
   TWILIO_ACCOUNT_SID=your_twilio_sid
   TWILIO_AUTH_TOKEN=your_twilio_token
   GOOGLE_CALENDAR_CREDENTIALS=path_to_credentials.json
   ```

5. **Start the server**
   ```bash
   rails server
   ```

6. **Visit the application**
   - Chat Interface: `http://localhost:3000/chats`
   - Lead Dashboard: `http://localhost:3000/leads`

## 📱 API Integration

### Voice Assistant Integration

The Rails app works seamlessly with the FastAPI voice assistant:

```ruby
# Lead creation from voice calls
POST /leads
Content-Type: application/json

{
  "lead": {
    "email": "customer@example.com",
    "payload": {
      "source": "voice_call_ai",
      "transcription_sid": "GT123...",
      "contact_info": {
        "name": "John Doe",
        "phone": "555-123-4567",
        "email": "customer@example.com"
      },
      "interests": ["1BHK", "Swimming Pool"],
      "appointments": {
        "requested": true,
        "status": "requested"
      },
      "lead_score": 85
    }
  }
}
```

### Chat Auto-close System

Intelligent conversation ending with two-step confirmation:

```ruby
# Auto-close detection patterns
completion_signals = [
  "contact information provided",
  "appointment scheduled", 
  "tour booked",
  "goodbye expressions"
]

# User confirmation required
confirmation_patterns = [
  "yes", "that's all", "no more questions",
  "close chat", "end conversation"
]
```

## 🎯 Lead Scoring Algorithm

Our intelligent scoring system evaluates leads based on:

| Category | Points | Description |
|----------|--------|-------------|
| **Contact Info** | | |
| Email provided | +30 | Valid email for follow-up |
| Phone number | +25 | Direct contact method |
| Name provided | +15 | Personal connection |
| **Engagement** | | |
| Appointment requested | +20 | High purchase intent |
| Interests mentioned | +10 | Specific requirements |
| Long conversation (5+ messages) | +10 | High engagement |

**Classification:**
- 🔥 **Hot Leads** (80-100): Ready to close
- 🌡️ **Warm Leads** (60-79): Good prospects
- ❄️ **Cold Leads** (0-59): Need nurturing

## 📊 Dashboard Features

### Lead Management Interface

- **📞 Voice Call Filter**: View leads from AI voice assistant
- **💬 Chat Filter**: View leads from website chat
- **🎯 Quality Filters**: Hot leads, email provided, appointments
- **📈 Real-time Stats**: Live updates on lead metrics
- **🔍 Advanced Search**: Filter by multiple criteria

### Lead Details View

Each lead displays:
- **Contact Information**: Name, email, phone
- **Source Identification**: Voice call vs. web chat
- **Interest Categories**: Apartment preferences
- **Conversation Summary**: Key interaction points
- **Appointment Status**: Scheduling information
- **Lead Score**: Quality assessment

## 🎨 UI/UX Features

- **Responsive Design**: Works on desktop and mobile
- **Real-time Updates**: Live chat and lead updates
- **Visual Indicators**: Color-coded lead sources and scores
- **Intuitive Navigation**: Easy switching between chats and leads
- **Modern Interface**: Clean, professional design with Tailwind CSS

## 🔧 Configuration

### Chat Auto-close Settings

```ruby
# app/models/chat.rb
COMPLETION_SIGNALS = [
  'contact_info_provided',
  'appointment_scheduled',
  'tour_booked'
].freeze

CONFIRMATION_PATTERNS = [
  /\b(yes|yeah|yep)\b/i,
  /\bthat'?s all\b/i,
  /\bno more questions?\b/i
].freeze
```

### Lead Scoring Configuration

```ruby
# app/models/lead.rb
SCORING_RULES = {
  email: 30,
  phone: 25, 
  name: 15,
  appointment: 20,
  interests: 10,
  engagement: 10
}.freeze
```

## 📈 Analytics & Metrics

Track key performance indicators:

- **Lead Volume**: Total leads by source
- **Conversion Rates**: Chat to lead conversion
- **Quality Distribution**: Hot/Warm/Cold breakdown
- **Response Times**: Average handling time
- **Appointment Bookings**: Scheduling success rate

## 🎥 Demo Features

Perfect for hackathon demonstrations:

1. **Live Voice Integration**: Show calls creating leads automatically
2. **Real-time Chat**: Demonstrate live visitor interaction
3. **Instant Lead Scoring**: Watch scores calculate in real-time
4. **Source Differentiation**: Toggle between voice and chat leads
5. **Calendar Integration**: Show automatic appointment booking

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🏆 Hackathon Project

Built for demonstration of:
- **AI Integration** in real estate customer service
- **Omnichannel Lead Capture** from voice and chat
- **Intelligent Lead Scoring** and prioritization
- **Modern Rails Architecture** with real-time features
- **API Integration** between Rails and FastAPI services

---

## 🎯 Quick Demo Script

For hackathon presentations:

1. **Show Voice Integration**: Call the Twilio number → AI assistant → Automatic lead creation
2. **Demonstrate Chat**: Visitor interaction → Lead capture → Auto-close with confirmation
3. **Highlight Analytics**: Filter by source → Show lead scoring → Quality breakdown
4. **Calendar Integration**: Book appointment → Show Google Calendar event
5. **Mobile Responsive**: Access dashboard on mobile device

**Perfect for showcasing the future of real estate customer service!** 🏠✨
