# Project Refactoring Migration Guide

## What Changed?

This project has been refactored to follow modern Flutter best practices and improve maintainability, security, and scalability.

### 🏗️ New Folder Structure

```
lib/
├── constants/        # App-wide constants and configuration
│   └── app_constants.dart
├── models/          # Data models
├── providers/       # State management (Provider pattern)
│   ├── auth_provider.dart
│   └── wallet_provider.dart
├── screens/         # All screen/page widgets
│   ├── homepage.dart
│   ├── sign_in_screen.dart
│   ├── wallet_page.dart
│   └── ...
├── services/        # Business logic and API services
│   ├── api_service.dart
│   └── auth_service.dart
├── utils/           # Utility functions and helpers
│   ├── validation_utils.dart
│   ├── mobile_utils.dart
│   └── web_utils.dart
├── widgets/         # Reusable UI components
│   ├── custom_button.dart
│   ├── custom_text_field.dart
│   ├── common_widgets.dart
│   └── graph.dart
├── firebase_options.dart
└── main.dart
```

### 🔐 Security Improvements

1. **Removed hardcoded credentials** - All sensitive data moved to environment variables
2. **API credentials** are now loaded from `.env` file (never commit this!)
3. **Prepared for backend separation** - PHP API should be moved to separate repository

### 🎯 State Management

- **Added Provider** package for state management
- Created `AuthProvider` and `WalletProvider` for managing app state
- Main app now wrapped with `MultiProvider`

### 🌐 Networking

- **Centralized API Service** - All HTTP requests go through `ApiService`
- **Proper error handling** - No more empty catch blocks
- **Timeout handling** - Requests timeout after 30 seconds
- **User-friendly error messages** - Clear feedback for users

### 📝 Validation

- **Validation utilities** - Reusable validation functions
- Email, password, phone, and amount validation
- Consistent validation across the app

### 🎨 Reusable Widgets

- `CustomButton` - Standardized button component
- `CustomTextField` - Consistent text input fields
- `LoadingOverlay` - Loading states
- Dialog helpers - Error, success, and confirmation dialogs

## 📋 Required Actions

### 1. Install Dependencies

```bash
flutter pub get
```

This will install the new `provider` package.

### 2. Update Import Statements

All screen imports need to be updated. For example:

**Before:**
```dart
import 'sign_in_screen.dart';
import 'homepage.dart';
```

**After:**
```dart
import 'screens/sign_in_screen.dart';
import 'screens/homepage.dart';
```

### 3. Set Up Environment Variables

For the backend API (`lib/api.php`), create a `.env` file:

```bash
cp .env.example .env
```

Then fill in your actual credentials (DO NOT commit this file!).

### 4. Update Screen Files

Each screen file needs its imports updated to reference the new structure:

```dart
import '../services/api_service.dart';
import '../constants/app_constants.dart';
import '../widgets/custom_button.dart';
import '../utils/validation_utils.dart';
```

### 5. Use Provider for State Management

Update your widgets to use Provider:

```dart
// Access auth state
final authProvider = Provider.of<AuthProvider>(context);

// Or use Consumer
Consumer<AuthProvider>(
  builder: (context, authProvider, child) {
    return Text(authProvider.userEmail ?? '');
  },
)
```

### 6. Use ApiService for Network Calls

Replace direct HTTP calls with ApiService:

**Before:**
```dart
final response = await http.post(
  Uri.parse('https://api.example.com/login'),
  body: json.encode({'email': email}),
);
```

**After:**
```dart
final apiService = ApiService();
final response = await apiService.post(
  '/login',
  body: {'email': email},
);
```

### 7. Use AuthService for Firebase Authentication

**Before:**
```dart
await FirebaseAuth.instance.signInWithEmailAndPassword(
  email: email,
  password: password,
);
```

**After:**
```dart
final authService = AuthService();
await authService.signInWithEmailAndPassword(
  email: email,
  password: password,
);
```

## 🚀 Next Steps

1. **Move backend API** - Move `lib/api.php` to a separate repository
2. **Deploy backend** - Host the API on a secure server
3. **Update API base URL** - Configure `API_BASE_URL` environment variable
4. **Add tests** - Write unit and widget tests
5. **Improve documentation** - Document all APIs and services

## ⚠️ Breaking Changes

- File locations have changed - update all imports
- State is now managed through Provider - update state access patterns
- API calls should go through ApiService - update network code
- Firebase auth should use AuthService - update authentication code

## 📚 Additional Resources

- [Provider Package Documentation](https://pub.dev/packages/provider)
- [Flutter Architecture Patterns](https://docs.flutter.dev/development/data-and-backend/state-mgmt/options)
- [Firebase Authentication](https://firebase.google.com/docs/auth/flutter/start)

## 🐛 Troubleshooting

**Import errors:**
- Run `flutter pub get`
- Update import paths to new structure
- Use relative imports (../) for accessing parent directories

**Provider errors:**
- Ensure MultiProvider is in main.dart
- Access providers using `Provider.of<T>(context)` or `Consumer<T>`

**API errors:**
- Check that backend is running
- Verify API_BASE_URL is correctly configured
- Check network connectivity

---

**Need help?** Check the code review report or contact the development team.
