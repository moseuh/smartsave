# Backend API Requirements for SmartSave App

## 1. **Register API Update** - `/api/register` (POST)

### Current Issue:
The API is returning an error saying selfie and ID pictures are required during signup.

### Required Changes:
**Make selfie_image and id_document_image OPTIONAL** during registration.

### Request Body:
```json
{
  "full_name": "string",
  "email": "string",
  "phone_number": "string",
  "password": "string",
  "date_of_birth": "1990-01-01",  // Placeholder
  "national_id": "PENDING"         // Placeholder
}
```

### Response:
```json
{
  "status": "success",
  "message": "User registered successfully",
  "userId": 123,
  "profile_completed": false
}
```

### Database Changes Needed:
```sql
ALTER TABLE users 
MODIFY COLUMN selfie_image VARCHAR(255) NULL,
MODIFY COLUMN id_document_image VARCHAR(255) NULL,
MODIFY COLUMN date_of_birth DATE NULL,
MODIFY COLUMN national_id VARCHAR(50) NULL;
```

---

## 2. **Complete Profile API** - `/api/complete-profile` (POST)

### Purpose:
Users complete their profile AFTER signup with KYC documents.

### Request Body (multipart/form-data):
```
user_id: string (required)
date_of_birth: string (required) - Format: "YYYY-MM-DD"
national_id: string (required) - 6-20 alphanumeric characters
phone_number: string (required) - Full international format (e.g., "+254712345678")
selfie_image: file (OPTIONAL - not validated on frontend)
id_document_image: file (OPTIONAL - not validated on frontend)
```

### Required Changes:
**Make selfie_image and id_document_image OPTIONAL fields**
**Add phone_number field (REQUIRED) - This captures phone for Google signup users**

The frontend now allows users to skip uploading photos, so backend should:
1. Accept requests without these files
2. Set default values (NULL or empty string) if not provided
3. Still return success if only date_of_birth, national_id, and phone_number are provided
4. Store phone_number with country code (e.g., "+254712345678")

### Response:
```json
{
  "status": "success",
  "message": "Profile completed successfully",
  "profile_completed": true
}
```

### Error Response:
```json
{
  "status": "error",
  "message": "Error description"
}
```

### Database Update:
```sql
UPDATE users 
SET 
  date_of_birth = ?,
  national_id = ?,
  phone_number = ?,           -- NEW FIELD (Store with country code)
  selfie_image = ?,           -- Can be NULL
  id_document_image = ?,      -- Can be NULL
  profile_completed = true,
  updated_at = NOW()
WHERE user_id = ?;
```

---

## 3. **Google Signup API** - `/api/google-signup` (POST)

### Purpose:
Register new users who sign up with Google OAuth.
**Note: Phone number will be collected during profile completion, not at signup.**

### Request Body:
```json
{
  "email": "string",
  "google_id": "string",
  "name": "string",
  "photo_url": "string"
}
```

### Logic:
1. Check if user with this email already exists
2. If exists, return error "Email already registered"
3. If new, create user with:
   - email, google_id, name, photo_url
   - Set profile_completed = false
   - Set password as NULL (Google auth user)
   - Set date_of_birth and national_id as NULL
4. Return userId

### Response:
```json
{
  "status": "success",
  "userId": 123,
  "message": "Google signup successful",
  "profile_completed": false
}
```

---

## 4. **Google Login API (Already Exists)** - `/api/google-login` (POST)

### Current Implementation:
Should check if user exists and return:
```json
{
  "status": "success",
  "userId": 123,
  "user_name": "John Doe",
  "profile_completed": true/false
}
```

### IMPORTANT: Must include `profile_completed` field in response.

---

## 5. **Regular Login API** - `/api/login` (POST)

### Purpose:
Authenticate users and return profile completion status.

### Request Body:
```json
{
  "email": "string",
  "password": "string"
}
```

### Response:
```json
{
  "status": "success",
  "userId": 123,
  "user_name": "John Doe",
  "profile_completed": true/false
}
```

### IMPORTANT: Must include `profile_completed` field in response.

The app checks this status every time user logs in to determine if profile completion screen should appear.

---

## Summary of Required Backend Changes:

### ✅ Immediate Changes Needed:

1. **`/api/register`**
   - Remove validation requiring selfie_image and id_document_image
   - Make these fields NULL in database
   - Allow registration with just basic info
   - Return profile_completed: false

2. **`/api/complete-profile`**
   - Make selfie_image and id_document_image OPTIONAL
   - Add phone_number field (REQUIRED)
   - Accept request even if only date_of_birth, national_id, and phone_number provided
   - Store NULL values if images not uploaded
   - Set profile_completed = true on success

3. **`/api/google-signup`** (NEW ENDPOINT)
   - Create new endpoint for Google OAuth registration
   - Check for existing email
   - Create user with profile_completed = false
   - Return userId for profile completion flow

4. **`/api/login`** (UPDATE)
   - Must return profile_completed field in response
   - App checks this to redirect to profile completion if needed

5. **`/api/google-login`** (UPDATE)
   - Must return profile_completed field in response
   - Must return user_name field in response
   - App checks this to redirect to profile completion if needed

### Database Schema Changes:
```sql
ALTER TABLE users 
MODIFY COLUMN selfie_image VARCHAR(255) NULL,
MODIFY COLUMN id_document_image VARCHAR(255) NULL,
MODIFY COLUMN date_of_birth DATE NULL,
MODIFY COLUMN national_id VARCHAR(50) NULL;
```

### Testing:
1. Test normal signup without errors
2. Test profile completion with only date/national_id (no images)
3. Test Google signup flow
4. Verify users can skip profile completion and access dashboard
