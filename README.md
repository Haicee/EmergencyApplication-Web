# ResME Emergency Management System

A comprehensive emergency management system with user management, station management, and real-time data handling.

## 🏗️ Architecture

- **Frontend**: React.js with Tailwind CSS
- **Backend**: Node.js with Express
- **Database**: Firebase Realtime Database
- **Authentication**: Firebase Admin SDK

## 📁 Project Structure

```
Admin/
├── backend/                 # Backend server
│   ├── config/
│   │   └── firebase.js     # Firebase admin configuration
│   ├── routes/
│   │   └── users.js        # User management routes
│   ├── package.json        # Backend dependencies
│   └── server.js           # Express server
├── my-app/                 # Frontend React app
│   ├── src/
│   │   ├── services/
│   │   │   └── api.js      # API service layer
│   │   ├── ManageUsers.jsx # User management component
│   │   └── ...             # Other React components
│   └── package.json        # Frontend dependencies
└── README.md
```

## 🚀 Quick Start

### Prerequisites

- Node.js (v14 or higher)
- npm or yarn
- Firebase project with Realtime Database enabled

### 1. Backend Setup

```bash
# Navigate to backend directory
cd backend

# Install dependencies
npm install

# Create environment file
# Copy the Firebase service account key to .env file
# (You'll need to get this from Firebase Console)

# Start the server
npm run dev
```

The backend will run on `http://localhost:5000`

### 2. Frontend Setup

```bash
# Navigate to frontend directory
cd my-app

# Install dependencies
npm install

# Start the development server
npm start
```

The frontend will run on `http://localhost:3000`

## 🔧 Firebase Setup

### 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or use existing one
3. Enable Realtime Database
4. Set up security rules for Realtime Database

### 2. Get Service Account Key

1. Go to Project Settings > Service Accounts
2. Click "Generate new private key"
3. Download the JSON file
4. Copy the values to your backend `.env` file

### 3. Environment Variables

Create a `.env` file in the backend directory:

```env
# Firebase Configuration
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY_ID=your-private-key-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYOUR_PRIVATE_KEY_HERE\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com
FIREBASE_CLIENT_ID=your-client-id
FIREBASE_AUTH_URI=https://accounts.google.com/o/oauth2/auth
FIREBASE_TOKEN_URI=https://oauth2.googleapis.com/token
FIREBASE_AUTH_PROVIDER_X509_CERT_URL=https://www.googleapis.com/oauth2/v1/certs
FIREBASE_CLIENT_X509_CERT_URL=https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-xxxxx%40your-project.iam.gserviceaccount.com

# Server Configuration
PORT=5000
NODE_ENV=development
```

## 📊 API Endpoints

### Citizens
- `GET /api/users/citizens` - Get all citizens
- `GET /api/users/citizens/:id` - Get citizen by ID
- `POST /api/users/citizens` - Create new citizen
- `PUT /api/users/citizens/:id` - Update citizen
- `DELETE /api/users/citizens/:id` - Delete citizen

### Stations
- `GET /api/users/stations` - Get all stations
- `GET /api/users/stations/:id` - Get station by ID
- `POST /api/users/stations` - Create new station
- `PUT /api/users/stations/:id` - Update station
- `DELETE /api/users/stations/:id` - Delete station

### Officers
- `POST /api/users/stations/:stationId/officers` - Add officer to station
- `PUT /api/users/stations/:stationId/officers/:officerId` - Update officer
- `DELETE /api/users/stations/:stationId/officers/:officerId` - Delete officer

## 🔒 Security

- CORS enabled for frontend-backend communication
- Helmet.js for security headers
- Input validation and sanitization
- Firebase Admin SDK for secure database access

## 🛠️ Development

### Backend Development

```bash
cd backend
npm run dev  # Starts with nodemon for auto-reload
```

### Frontend Development

```bash
cd my-app
npm start    # Starts React development server
```

### Database Structure

The Firebase Realtime Database structure:

```json
{
  "citizens": {
    "citizen_id": {
      "initials": "JS",
      "name": "John Smith",
      "role": "Citizen",
      "contact": "09548796512",
      "gender": "Male",
      "address": "Calumpang, General Santos City",
      "genderColor": "blue",
      "pwd": false,
      "medical": false,
      "password": "************",
      "createdAt": "2024-01-20T10:30:00.000Z"
    }
  },
  "stations": {
    "station_id": {
      "name": "Police Station 1",
      "address": "Pendatun Avenue, General Santos City",
      "officers": {
        "officer_id": {
          "initials": "JS",
          "name": "Officer John Smith",
          "role": "Desk Officer",
          "status": "Active",
          "createdAt": "2024-01-20T10:30:00.000Z"
        }
      },
      "createdAt": "2024-01-20T10:30:00.000Z"
    }
  }
}
```

## 🚨 Troubleshooting

### Common Issues

1. **CORS Errors**: Make sure the backend is running on port 5000
2. **Firebase Connection**: Verify your service account credentials in `.env`
3. **Port Conflicts**: Change the port in `.env` if 5000 is occupied

### Debug Mode

Set `NODE_ENV=development` in your `.env` file for detailed error messages.

## 📝 License

This project is licensed under the ISC License.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📞 Support

For support and questions, please contact the development team. 