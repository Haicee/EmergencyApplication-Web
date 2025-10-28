# 🔄 Firebase Migration Guide
## From `emergency-73ada` (Free Plan) → `resmeapp-1` (Blaze Plan)

---

## ✅ What's Been Done

### 1. Frontend Configuration Updated
- ✅ Updated `my-app/src/firebase.js` with new project credentials
- ✅ New project ID: `resmeapp-1`
- ✅ New database URL: `https://resmeapp-1-default-rtdb.firebaseio.com`

### 2. Backend Configuration Updated
- ✅ Updated `backend/config/firebase.js` with new project ID
- ✅ Updated database URL reference
- ✅ Created `.env.template` file for new credentials

---

## 📋 Next Steps (Action Required)

### Step 1: Get Firebase Service Account Credentials

1. **Go to Firebase Console**
   - Visit: https://console.firebase.google.com/
   - Select project: **resmeapp-1**

2. **Navigate to Service Accounts**
   - Click the ⚙️ (gear icon) → **Project Settings**
   - Go to **Service Accounts** tab
   - Click **Generate New Private Key** button
   - Download the JSON file (keep it secure!)

3. **Update Backend .env File**
   ```bash
   # In the backend folder
   # Copy the template
   cp .env.template .env
   
   # Or on Windows
   copy .env.template .env
   ```

4. **Fill in the .env file with values from the downloaded JSON:**
   - Open the downloaded JSON file
   - Copy each value to the corresponding field in `.env`
   
   **JSON → .env Mapping:**
   ```
   project_id          → FIREBASE_PROJECT_ID
   private_key_id      → FIREBASE_PRIVATE_KEY_ID
   private_key         → FIREBASE_PRIVATE_KEY
   client_email        → FIREBASE_CLIENT_EMAIL
   client_id           → FIREBASE_CLIENT_ID
   client_x509_cert_url → FIREBASE_CLIENT_X509_CERT_URL
   ```

### Step 2: Enable Firebase Services

1. **Enable Realtime Database**
   - Firebase Console → Build → Realtime Database
   - Click **Create Database**
   - Choose location: **United States** (or closest to your users)
   - Start in **Test Mode** (we'll add security rules later)

2. **Enable Authentication** (Optional but recommended)
   - Firebase Console → Build → Authentication
   - Click **Get Started**
   - Enable **Email/Password** provider

3. **Enable Storage** (For future features)
   - Firebase Console → Build → Storage
   - Click **Get Started**
   - Start in **Test Mode**

4. **Enable Analytics** (Already configured)
   - Should be auto-enabled with your config

### Step 3: Set Up Security Rules

#### **Realtime Database Rules**
Go to: Firebase Console → Realtime Database → Rules

```json
{
  "rules": {
    ".read": false,
    ".write": false,
    
    "users": {
      ".read": "auth != null",
      "$userId": {
        ".write": "auth != null"
      }
    },
    
    "AuthAccounts": {
      ".read": "auth != null",
      "$username": {
        ".write": "auth != null"
      }
    },
    
    "Desk Officer": {
      ".read": "auth != null",
      "$station": {
        ".write": "auth != null"
      }
    },
    
    "Responders": {
      ".read": "auth != null",
      "$station": {
        ".write": "auth != null"
      }
    },
    
    "StationsCallLogs": {
      ".read": "auth != null",
      ".write": "auth != null"
    },
    
    "emergencyCalls": {
      ".read": "auth != null",
      ".write": "auth != null"
    },
    
    "stations": {
      ".read": "auth != null",
      ".write": "auth != null"
    }
  }
}
```

**Note:** These are basic rules. We'll implement more secure rules later.

### Step 4: Data Migration (Optional)

If you have existing data in the old database:

#### **Option A: Manual Export/Import (Recommended for small data)**

1. **Export from old database:**
   - Go to old Firebase project: `emergency-73ada`
   - Realtime Database → ⋮ (three dots) → Export JSON
   - Save the file

2. **Import to new database:**
   - Go to new Firebase project: `resmeapp-1`
   - Realtime Database → ⋮ (three dots) → Import JSON
   - Select the exported file

#### **Option B: Programmatic Migration (For large data)**

I can create a migration script if needed. Let me know!

### Step 5: Create Initial Admin Account

1. **Generate a secure setup token:**
   - Visit: https://www.uuidgenerator.net/
   - Copy the generated UUID
   - Add it to `.env` as `ADMIN_SETUP_TOKEN`

2. **Start the backend server:**
   ```bash
   cd backend
   npm install
   npm run dev
   ```

3. **Create admin account using API:**
   ```bash
   # Using curl (Git Bash or WSL)
   curl -X POST http://localhost:5000/api/auth/bootstrap-admin \
     -H "Content-Type: application/json" \
     -H "x-admin-setup-token: YOUR_TOKEN_HERE" \
     -d '{"username":"admin","password":"YourSecurePassword123","fullName":"Admin User"}'
   
   # Or using PowerShell
   $headers = @{
       "Content-Type" = "application/json"
       "x-admin-setup-token" = "YOUR_TOKEN_HERE"
   }
   $body = @{
       username = "admin"
       password = "YourSecurePassword123"
       fullName = "Admin User"
   } | ConvertTo-Json
   
   Invoke-RestMethod -Uri "http://localhost:5000/api/auth/bootstrap-admin" -Method Post -Headers $headers -Body $body
   ```

### Step 6: Test Everything

1. **Start Backend:**
   ```bash
   cd backend
   npm run dev
   ```
   Should see: `🚀 ResME Backend Server running on port 5000`

2. **Start Frontend:**
   ```bash
   cd my-app
   npm start
   ```
   Should open: `http://localhost:3000`

3. **Test Login:**
   - Use the admin credentials you created
   - Should see the dashboard

4. **Test Features:**
   - ✅ Dashboard loads with statistics
   - ✅ Manage Users page works
   - ✅ Can create/edit/delete users
   - ✅ Emergency Calls page loads
   - ✅ Report Status page loads

---

## 🎉 Benefits of Blaze Plan

### What You Can Now Do:

1. **Cloud Functions**
   - Automated tasks (e.g., auto-assign responders)
   - Scheduled jobs (e.g., daily reports)
   - Database triggers (e.g., send notification on new emergency)

2. **Firebase Storage**
   - Upload profile pictures
   - Store emergency evidence photos
   - Document attachments

3. **Cloud Messaging (FCM)**
   - Push notifications to mobile apps
   - Real-time emergency alerts
   - Broadcast messages to responders

4. **No Limits**
   - Unlimited simultaneous connections
   - No storage limits (pay as you go)
   - Production-ready scaling

5. **Advanced Features**
   - Firebase Extensions
   - Cloud Firestore (if needed)
   - Firebase Hosting for deployment

---

## 💰 Cost Estimation

**Blaze Plan is Pay-As-You-Go:**

For a small-to-medium emergency system:
- **Realtime Database**: ~$5/month (1GB storage, 10GB download)
- **Cloud Functions**: ~$0-5/month (first 2M invocations free)
- **Storage**: ~$0-5/month (first 5GB free)
- **Hosting**: Free (10GB transfer/month)

**Estimated Total: $5-15/month** for moderate usage

---

## 🔒 Security Improvements to Implement

After migration, we should:

1. **Password Hashing**
   - Implement bcrypt for password storage
   - Remove plain text passwords

2. **JWT Authentication**
   - Replace localStorage with secure tokens
   - Add token expiration

3. **Input Validation**
   - Add validation middleware
   - Sanitize all inputs

4. **Rate Limiting**
   - Prevent brute force attacks
   - Limit API calls per user

5. **Environment Variables**
   - Use Firebase Secret Manager for production
   - Never commit .env files

---

## 📞 Need Help?

If you encounter any issues:

1. **Check Firebase Console Logs**
   - Functions → Logs (if using Cloud Functions)
   - Realtime Database → Usage tab

2. **Check Backend Logs**
   - Look at terminal where backend is running
   - Check for connection errors

3. **Verify Credentials**
   - Ensure .env file has correct values
   - Check for extra spaces or quotes

4. **Database Rules**
   - Temporarily set to test mode if having permission issues
   - Remember to secure them later!

---

## ✅ Migration Checklist

- [ ] Downloaded service account JSON from Firebase Console
- [ ] Updated backend/.env with new credentials
- [ ] Enabled Realtime Database in new project
- [ ] Set up basic security rules
- [ ] Migrated existing data (if any)
- [ ] Created initial admin account
- [ ] Tested backend server connection
- [ ] Tested frontend login
- [ ] Verified all features work
- [ ] Updated documentation

---

**Ready to proceed? Let me know if you need help with any step!** 🚀
