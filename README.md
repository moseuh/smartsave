# SmartSave - Mobile Savings Application

A modern Flutter mobile application for savings management, goals tracking, loans, and financial services.

## 🚀 Recent Refactoring (January 2026)

This project has undergone a major refactoring to improve:
- **Security** - Removed hardcoded credentials, moved to environment variables
- **Architecture** - Clean separation of concerns with proper folder structure
- **State Management** - Implemented Provider pattern
- **Code Quality** - Centralized API services, proper error handling
- **Maintainability** - Reusable widgets, validation utilities

**📖 See [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) for detailed migration instructions.**

## 📁 Project Structure

```
lib/
├── constants/     # Configuration and constants
├── models/        # Data models
├── providers/     # State management
├── screens/       # UI screens
├── services/      # Business logic and API services
├── utils/         # Helper functions
├── widgets/       # Reusable UI components
└── main.dart      # App entry point
```

## 🔐 Security Setup

### 1. Environment Variables

Copy the example environment file:
```bash
cp .env.example .env
```

Then edit `.env` with your actual credentials (NEVER commit this file):
```env
DB_HOST=localhost
DB_USER=your_database_user
DB_PASS=your_database_password
# ... etc
```

### 2. Backend Separation

⚠️ **IMPORTANT**: The PHP backend (`lib/api.php`) must be moved to a separate repository and deployed on a secure server. See [BACKEND_MIGRATION_TODO.md](BACKEND_MIGRATION_TODO.md).

## 🛠️ Getting Started

### Prerequisites

- Flutter SDK (>=3.6.1)
- Dart SDK
- Firebase project configured
- Android Studio / VS Code

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd smartsave
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Add `google-services.json` (Android)
   - Add `GoogleService-Info.plist` (iOS)
   - Update `firebase_options.dart`

4. **Run the app**
   ```bash
   flutter run
   ```

## 📦 Dependencies

### Core
- `flutter` - UI framework
- `provider` - State management
- `http` - HTTP client

### Firebase
- `firebase_core` - Firebase initialization
- `firebase_auth` - Authentication
- `firebase_analytics` - Analytics
- `firebase_crashlytics` - Crash reporting

### UI/UX
- `fl_chart` - Charts and graphs
- `cached_network_image` - Image caching
- `flutter_spinkit` - Loading animations

### Utilities
- `shared_preferences` - Local storage
- `connectivity_plus` - Network connectivity
- `intl` - Internationalization
- `url_launcher` - Open URLs

See [pubspec.yaml](pubspec.yaml) for complete list.

## 🏗️ Architecture

### State Management
Uses **Provider** pattern for state management:
- `AuthProvider` - Authentication state
- `WalletProvider` - Wallet and transactions

### API Service
Centralized `ApiService` for all network requests with:
- Automatic error handling
- Timeout configuration
- Token management
- Standardized responses

### Authentication
`AuthService` handles:
- Email/password authentication
- Google Sign-In
- Firebase integration
- Session management

## 🧪 Testing

```bash
# Run tests
flutter test

# Run with coverage
flutter test --coverage
```

## 📱 Features

- 💰 **Wallet Management** - Track balance and transactions
- 🎯 **Savings Goals** - Set and monitor savings goals
- 📊 **Analytics** - View financial graphs and statistics
- 💳 **Loans** - Apply for and manage loans
- 🔐 **Secure Authentication** - Email and Google Sign-In
- 📈 **Leaderboard** - Gamification features
- 🎓 **Scholarships** - Browse funding opportunities
- 💼 **Jobs** - Find employment opportunities

## 🔒 Security

- ✅ No hardcoded credentials
- ✅ Environment-based configuration
- ✅ Firebase authentication
- ✅ Secure token management
- ✅ Input validation
- ⚠️ Backend API must be moved to separate server (see BACKEND_MIGRATION_TODO.md)

## 📚 Documentation

- [Migration Guide](MIGRATION_GUIDE.md) - Refactoring details
- [Code Review Report](CODE_REVIEW_REPORT.md) - Security audit findings
- [Backend Migration](BACKEND_MIGRATION_TODO.md) - Backend separation guide

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is proprietary software.

## 👨‍💻 Development Team

- **Ngare Anthony** - Senior Software Engineer

## 📞 Support

For issues or questions, please contact the development team.

---

**Last Updated:** January 10, 2026

