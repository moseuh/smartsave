# Quick Reference Guide - New Architecture

## 🚀 Using the New Architecture

### Importing Files

```dart
// From lib/main.dart
import 'screens/homepage.dart';
import 'providers/auth_provider.dart';
import 'services/api_service.dart';

// From lib/screens/homepage.dart (going up one level)
import '../services/api_service.dart';
import '../providers/wallet_provider.dart';
import '../widgets/custom_button.dart';
import '../constants/app_constants.dart';

// From lib/widgets/custom_button.dart
import 'package:flutter/material.dart';
```

### Using Provider for State Management

```dart
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

// In your widget
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Method 1: Provider.of
    final authProvider = Provider.of<AuthProvider>(context);
    
    // Method 2: Consumer (rebuilds only this widget)
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isLoading) {
          return CircularProgressIndicator();
        }
        return Text(authProvider.userEmail ?? 'Not logged in');
      },
    );
    
    // Method 3: context.read (doesn't listen to changes)
    onPressed: () {
      context.read<AuthProvider>().signOut();
    }
  }
}
```

### Using ApiService

```dart
import '../services/api_service.dart';
import '../constants/app_constants.dart';

class MyService {
  final ApiService _apiService = ApiService();
  
  // GET request
  Future<void> fetchData() async {
    try {
      final response = await _apiService.get(
        AppConstants.userProfileEndpoint,
        requiresAuth: true,
      );
      // Handle response
      print(response['data']);
    } catch (e) {
      // Error already logged by ApiService
      print('Error: $e');
    }
  }
  
  // POST request
  Future<void> createGoal(Map<String, dynamic> goalData) async {
    try {
      final response = await _apiService.post(
        AppConstants.goalsEndpoint,
        body: goalData,
        requiresAuth: true,
      );
      return response;
    } catch (e) {
      rethrow; // Re-throw to handle in UI
    }
  }
  
  // PUT request
  Future<void> updateProfile(Map<String, dynamic> profileData) async {
    await _apiService.put(
      AppConstants.userProfileEndpoint,
      body: profileData,
    );
  }
  
  // DELETE request
  Future<void> deleteGoal(String goalId) async {
    await _apiService.delete(
      '${AppConstants.goalsEndpoint}/$goalId',
    );
  }
}
```

### Using AuthService

```dart
import '../services/auth_service.dart';

class MyAuthWidget extends StatefulWidget {
  @override
  _MyAuthWidgetState createState() => _MyAuthWidgetState();
}

class _MyAuthWidgetState extends State<MyAuthWidget> {
  final AuthService _authService = AuthService();
  
  Future<void> _signIn() async {
    try {
      await _authService.signInWithEmailAndPassword(
        email: emailController.text,
        password: passwordController.text,
      );
      // Success - navigate
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
  
  Future<void> _signInWithGoogle() async {
    try {
      await _authService.signInWithGoogle();
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
  
  Future<void> _signOut() async {
    await _authService.signOut();
    Navigator.pushReplacementNamed(context, '/sign_in');
  }
}
```

### Using Validation Utils

```dart
import '../utils/validation_utils.dart';

class MyForm extends StatelessWidget {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _emailController,
            validator: ValidationUtils.validateEmail,
            decoration: InputDecoration(labelText: 'Email'),
          ),
          TextFormField(
            controller: _passwordController,
            validator: ValidationUtils.validatePassword,
            obscureText: true,
            decoration: InputDecoration(labelText: 'Password'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                // Form is valid
                _submitForm();
              }
            },
            child: Text('Submit'),
          ),
        ],
      ),
    );
  }
}
```

### Using Custom Widgets

```dart
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/common_widgets.dart';

class MyScreen extends StatelessWidget {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LoadingOverlay(
        isLoading: _isLoading,
        message: 'Signing in...',
        child: Column(
          children: [
            // Custom text field
            CustomTextField(
              controller: _emailController,
              labelText: 'Email',
              keyboardType: TextInputType.emailAddress,
              validator: ValidationUtils.validateEmail,
              prefixIcon: Icon(Icons.email),
            ),
            
            // Custom button
            CustomButton(
              text: 'Sign In',
              onPressed: _handleSignIn,
              isLoading: _isLoading,
              icon: Icons.login,
            ),
            
            // Show error dialog
            ElevatedButton(
              onPressed: () {
                showErrorDialog(context, 'Something went wrong!');
              },
              child: Text('Show Error'),
            ),
            
            // Show success dialog
            ElevatedButton(
              onPressed: () {
                showSuccessDialog(
                  context,
                  'Account created successfully!',
                  onClose: () {
                    Navigator.pop(context);
                  },
                );
              },
              child: Text('Show Success'),
            ),
            
            // Show confirmation dialog
            ElevatedButton(
              onPressed: () async {
                final confirmed = await showConfirmDialog(
                  context,
                  title: 'Delete Account',
                  message: 'Are you sure you want to delete your account?',
                  confirmText: 'Delete',
                  cancelText: 'Cancel',
                );
                if (confirmed) {
                  // Delete account
                }
              },
              child: Text('Delete Account'),
            ),
          ],
        ),
      ),
    );
  }
  
  void _handleSignIn() {
    // Sign in logic
  }
}
```

### Using Error Logger

```dart
import '../utils/error_logger.dart';

class MyService {
  Future<void> fetchData() async {
    ErrorLogger.logInfo('Fetching user data', context: 'UserService');
    
    try {
      final response = await apiService.get('/users');
      ErrorLogger.logSuccess('Data fetched successfully', context: 'UserService');
      return response;
    } catch (e, stackTrace) {
      ErrorLogger.logError(
        e,
        stackTrace: stackTrace,
        context: 'UserService.fetchData',
      );
      rethrow;
    }
  }
}
```

### Using Constants

```dart
import '../constants/app_constants.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Use app name
        Text(AppConstants.appName),
        
        // Use timeout for operations
        FutureBuilder(
          future: Future.delayed(AppConstants.apiTimeout),
          builder: (context, snapshot) {
            // ...
          },
        ),
        
        // Use error messages
        Text(AppConstants.networkError),
      ],
    );
  }
}
```

### Complete Example: Login Screen

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/common_widgets.dart';
import '../utils/validation_utils.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    
    final authProvider = context.read<AuthProvider>();
    
    final success = await authProvider.signInWithEmail(
      _emailController.text,
      _passwordController.text,
    );
    
    if (success) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      showErrorDialog(context, authProvider.errorMessage ?? 'Login failed');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sign In')),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return LoadingOverlay(
            isLoading: authProvider.isLoading,
            message: 'Signing in...',
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomTextField(
                      controller: _emailController,
                      labelText: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      validator: ValidationUtils.validateEmail,
                      prefixIcon: Icon(Icons.email),
                    ),
                    SizedBox(height: 16),
                    CustomTextField(
                      controller: _passwordController,
                      labelText: 'Password',
                      obscureText: true,
                      validator: ValidationUtils.validatePassword,
                      prefixIcon: Icon(Icons.lock),
                    ),
                    SizedBox(height: 24),
                    CustomButton(
                      text: 'Sign In',
                      onPressed: _handleLogin,
                      isLoading: authProvider.isLoading,
                      width: double.infinity,
                      icon: Icons.login,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
```

## 📝 Common Patterns

### Loading State
```dart
Consumer<MyProvider>(
  builder: (context, provider, child) {
    if (provider.isLoading) {
      return CircularProgressIndicator();
    }
    return MyWidget();
  },
)
```

### Error Handling
```dart
try {
  await apiService.post('/endpoint', body: data);
  showSuccessDialog(context, 'Success!');
} catch (e) {
  showErrorDialog(context, e.toString());
}
```

### Form Validation
```dart
Form(
  key: _formKey,
  child: Column(
    children: [
      TextFormField(validator: ValidationUtils.validateEmail),
      ElevatedButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            // Submit
          }
        },
      ),
    ],
  ),
)
```

---

**Tip:** Keep this file handy while refactoring existing screens!
