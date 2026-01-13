import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' show SocketException;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../widgets/graph.dart' as graph;

// Google Sign-In Client ID for Web
const String webClientId = '825042983512-b3eea0b1eg88hvqks2c7d0i989tj79qf.apps.googleusercontent.com';

// Helper function to parse error messages
String _parseErrorMessage(dynamic response, {String? fallbackMessage}) {
  String defaultMessage = fallbackMessage ?? 'An error occurred. Please try again.';
  // Handle non-JSON responses (e.g., HTML or plain text)
  if (response.headers['content-type']?.contains('application/json') != true) {
    if (response.statusCode == 404) {
      return 'Service unavailable. Please contact support.';
    } else if (response.statusCode == 500) {
      return 'Server error. Please try again later.';
    } else if (response.body.contains('<html') || response.body.contains('<br')) {
      return 'Unable to process your request. Please try again.';
    }
    return defaultMessage;
  }
  // Handle JSON responses
  try {
    final jsonResponse = jsonDecode(response.body);
    String? message = jsonResponse['message']?.toString().trim();
    if (message != null && message.isNotEmpty) {
      // Map server error messages to user-friendly versions (case-insensitive)
      switch (message.toLowerCase()) {
        case 'email and password required':
          return 'Please enter both email and password.';
        case 'user not found':
          return 'No account found with this email.';
        case 'invalid password':
          return 'Incorrect password. Please try again.';
        case 'aml check failed':
          return 'Login denied due to compliance restrictions.';
        case 'email already exists':
          return 'This email is already registered.';
        case 'invalid email format':
          return 'Please enter a valid email address.';
        case 'invalid phone number':
          return 'Please enter a valid phone number.';
        case 'invalid date of birth':
          return 'Please enter a valid date of birth (YYYY-MM-DD).';
        case 'weak password':
          return 'Password must be at least 8 characters long.';
        case 'both selfie and id document are required':
          return 'Please upload both a selfie and your ID document.';
        default:
          return message; // Use server-provided message if no specific mapping
      }
    }
  } catch (e) {
    debugPrint('Error parsing JSON response: $e');
  }
  return defaultMessage;
}

// Check internet connectivity using connectivity_plus
Future<bool> checkInternetConnectivity() async {
  try {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      debugPrint('No network connectivity detected.');
      return false;
    }
    final url = kIsWeb
        ? Uri.parse('https://jsonplaceholder.typicode.com/todos/1')
        : Uri.parse('http://127.0.0.1/apis/api.php/apis/');
    final response = await http.get(url).timeout(const Duration(seconds: 5));
    debugPrint('Connectivity check response: ${response.statusCode}');
    return response.statusCode == 200;
  } catch (e) {
    debugPrint('Connectivity check error: $e');
    return false;
  }
}

// Main App Entry
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Haba na Haba',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SplashScreen(),
      routes: {
        '/sign_in': (context) => const SignInScreen(),
        '/home': (context) => graph.SavingsDashboard(
              userId: ModalRoute.of(context)!.settings.arguments as String? ?? 'default_user',
            ),
      },
      onGenerateRoute: (settings) {
        debugPrint('onGenerateRoute called for: ${settings.name}');
        if (settings.name == '/sign_up') {
          final args = settings.arguments as Map<String, dynamic>? ?? {};
          return MaterialPageRoute(
            builder: (context) => SignUpScreen(
              isGoogleSignIn: args['isGoogleSignIn'] ?? false,
              googleName: args['googleName'],
              googleEmail: args['googleEmail'],
              googleIdToken: args['googleIdToken'],
              googlePhotoUrl: args['googlePhotoUrl'],
            ),
          );
        }
        return null;
      },
    );
  }
}

// Splash Screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future.delayed(const Duration(seconds: 3), () async {
      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('user_id');
        if (userId != null && userId.isNotEmpty) {
          Navigator.pushReplacementNamed(context, '/home', arguments: userId);
        } else {
          Navigator.pushReplacementNamed(context, '/sign_in');
        }
      }
    });
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[850],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Colors.yellow, Colors.amber],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.yellow.withOpacity(0.6),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 100,
                      height: 100,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('Asset loading error: $error');
                        return const Icon(Icons.error, size: 100, color: Colors.red);
                      },
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Haba na Haba',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.yellow),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== UPDATED SIGN UP SCREEN WITH ID DOCUMENT UPLOAD ====================

class SignUpScreen extends StatefulWidget {
  final bool isGoogleSignIn;
  final String? googleName;
  final String? googleEmail;
  final String? googleIdToken;
  final String? googlePhotoUrl;
  const SignUpScreen({
    super.key,
    this.isGoogleSignIn = false,
    this.googleName,
    this.googleEmail,
    this.googleIdToken,
    this.googlePhotoUrl,
  });
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _dobController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  XFile? _selfieImage;
  XFile? _idDocumentImage; // <-- NEW: ID document
  bool _isSelfieUploaded = false;
  bool _isIdDocumentUploaded = false; // <-- NEW

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.isGoogleSignIn) {
      _fullNameController.text = widget.googleName ?? '';
      _emailController.text = widget.googleEmail ?? '';
    }
  }

  // Pick Selfie (camera preferred on mobile)
  Future<void> _pickSelfie() async {
    if (kIsWeb) {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _selfieImage = pickedFile;
          _isSelfieUploaded = true;
        });
      }
      return;
    }
    var cameraStatus = await Permission.camera.request();
    var photosStatus = await Permission.photos.request();
    if (cameraStatus.isGranted || photosStatus.isGranted) {
      final pickedFile = await _picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        setState(() {
          _selfieImage = pickedFile;
          _isSelfieUploaded = true;
        });
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera or photos permission denied. Please enable in settings.')),
      );
      await openAppSettings();
    }
  }

  // Pick ID Document (gallery only)
  Future<void> _pickIdDocument() async {
    if (kIsWeb) {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _idDocumentImage = pickedFile;
          _isIdDocumentUploaded = true;
        });
      }
      return;
    }
    var photosStatus = await Permission.photos.request();
    if (photosStatus.isGranted) {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _idDocumentImage = pickedFile;
          _isIdDocumentUploaded = true;
        });
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photos permission denied. Please enable in settings.')),
      );
      await openAppSettings();
    }
  }

  Future<void> _registerUser() async {
    if (!await checkInternetConnectivity()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection. Please check your network.')),
      );
      return;
    }
    if (_fullNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _nationalIdController.text.isEmpty ||
        _dobController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }
    if (!widget.isGoogleSignIn &&
        (_passwordController.text.isEmpty || _confirmPasswordController.text.isEmpty)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter and confirm your password')),
      );
      return;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_emailController.text)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }
    if (!widget.isGoogleSignIn && _passwordController.text != _confirmPasswordController.text) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    // Require both images
    if (_selfieImage == null || !_isSelfieUploaded) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a selfie')),
      );
      return;
    }
    if (_idDocumentImage == null || !_isIdDocumentUploaded) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload your ID document (National ID)')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://apis.nebo.co.ke/apis/register'),
      );
      request.fields['full_name'] = _fullNameController.text;
      request.fields['email'] = _emailController.text;
      request.fields['phone_number'] = _phoneController.text;
      request.fields['national_id'] = _nationalIdController.text;
      request.fields['date_of_birth'] = _dobController.text;
      if (widget.isGoogleSignIn) {
        request.fields['google_id_token'] = widget.googleIdToken ?? '';
        request.fields['is_google_sign_in'] = 'true';
      } else {
        request.fields['password'] = _passwordController.text;
      }

      // Attach selfie
      if (_selfieImage != null) {
        if (kIsWeb) {
          final bytes = await _selfieImage!.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes('selfie', bytes, filename: 'selfie.jpg'),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath('selfie', _selfieImage!.path),
          );
        }
      }

      // Attach ID document
      if (_idDocumentImage != null) {
        if (kIsWeb) {
          final bytes = await _idDocumentImage!.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes('id_document', bytes, filename: 'id_document.jpg'),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath('id_document', _idDocumentImage!.path),
          );
        }
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final responseData = await streamedResponse.stream.bytesToString();

      debugPrint('Register API Response Status: ${streamedResponse.statusCode}');
      debugPrint('Register API Response Body: $responseData');

      // Mock a regular Response for error parsing
      final mockResponse = http.Response(responseData, streamedResponse.statusCode,
          headers: streamedResponse.headers);

      if (streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300 &&
          streamedResponse.headers['content-type']?.contains('application/json') == true) {
        final jsonResponse = jsonDecode(responseData);
        debugPrint('Parsed Register API Response: $jsonResponse');
        if (jsonResponse['status'] == 'success' || jsonResponse['status'] == 'warning') {
          final prefs = await SharedPreferences.getInstance();
          final userId = jsonResponse['userId'].toString();
          await prefs.setString('user_id', userId);
          await prefs.setString('user_name', _fullNameController.text);
          await prefs.setString('email', _emailController.text);
          await prefs.setString('phone_number', _phoneController.text);
          await prefs.setString('selfie_path', jsonResponse['selfie_path'] ?? widget.googlePhotoUrl ?? '');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration successful!')),
          );
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop(true);
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => graph.SavingsDashboard(userId: userId)),
            );
          }
        } else {
          final errorMessage = _parseErrorMessage(mockResponse, fallbackMessage: 'Registration failed. Please try again.');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      } else {
        final errorMessage = _parseErrorMessage(mockResponse, fallbackMessage: 'Registration failed. Please try again.');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e, stackTrace) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error sending registration request: $e');
      debugPrint('Stack trace: $stackTrace');
      String errorMessage;
      if (e is SocketException) {
        errorMessage = 'No internet connection. Please check your network.';
      } else if (e is TimeoutException) {
        errorMessage = 'Request timed out. Please try again.';
      } else {
        errorMessage = 'An error occurred during registration. Please try again.';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _nationalIdController.dispose();
    _dobController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Widget _buildTopNavigationBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          TextButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/sign_in');
            },
            child: Text(
              'Sign In',
              style: TextStyle(
                color: Colors.white,
                fontSize: MediaQuery.of(context).size.width * 0.035,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    TextEditingController? controller,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: MediaQuery.of(context).size.width * 0.035,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword ? obscureText : false,
          readOnly: readOnly,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF374151),
            prefixIcon: Icon(icon, color: Colors.grey[400]),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey[400],
                    ),
                    onPressed: onToggleObscure,
                  )
                : null,
            hintText: 'Enter your $label',
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: const Color(0xFF1F2937),
      body: Column(
        children: [
          _buildTopNavigationBar(),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: screenWidth * 0.06,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Please fill in all fields to sign up',
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildTextField(
                      label: 'Full name',
                      icon: Icons.person,
                      controller: _fullNameController,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Email',
                      icon: Icons.email,
                      controller: _emailController,
                      readOnly: widget.isGoogleSignIn,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Phone Number',
                      icon: Icons.phone,
                      controller: _phoneController,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'National ID',
                      icon: Icons.badge,
                      controller: _nationalIdController,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Date of Birth (YYYY-MM-DD)',
                      icon: Icons.calendar_today,
                      controller: _dobController,
                    ),
                    if (!widget.isGoogleSignIn) ...[
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'Password',
                        icon: Icons.lock,
                        isPassword: true,
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        onToggleObscure: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'Confirm Password',
                        icon: Icons.lock,
                        isPassword: true,
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        onToggleObscure: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Selfie Upload
                    GestureDetector(
                      onTap: _pickSelfie,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF374151),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isSelfieUploaded ? Icons.check_circle : Icons.camera_alt,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _isSelfieUploaded ? 'Selfie Uploaded' : 'Upload Selfie',
                              style: TextStyle(
                                color: _isSelfieUploaded ? Colors.green[300] : Colors.grey[400],
                                fontSize: screenWidth * 0.04,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // ID Document Upload - NEW
                    GestureDetector(
                      onTap: _pickIdDocument,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF374151),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isIdDocumentUploaded ? Icons.check_circle : Icons.description,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _isIdDocumentUploaded ? 'ID Document Uploaded' : 'Upload ID Document (National ID)',
                              style: TextStyle(
                                color: _isIdDocumentUploaded ? Colors.green[300] : Colors.grey[400],
                                fontSize: screenWidth * 0.04,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFC107),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _isLoading ? null : _registerUser,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                ),
                              )
                            : Text(
                                'Sign Up',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: screenWidth * 0.04,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushReplacementNamed(context, '/sign_in');
                        },
                        child: Text(
                          'Already have an account? Sign in',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: screenWidth * 0.035,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== SIGN IN SCREEN (FULL, UNCHANGED FROM YOUR ORIGINAL) ====================

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  @override
  void initState() {
    super.initState();
    _checkSavedCredentials();
  }
  Future<void> _checkSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('email');
    final savedPassword = prefs.getString('password');
    if (savedEmail != null && savedPassword != null) {
      setState(() {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
        _rememberMe = true;
      });
    }
  }
  Future<void> _loginUser() async {
    if (!await checkInternetConnectivity()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection. Please check your network.')),
      );
      return;
    }
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password')),
      );
      return;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_emailController.text)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });
    const String apiUrl = 'http://apis.nebo.co.ke/apis/login';
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      ).timeout(const Duration(seconds: 15));
      setState(() {
        _isLoading = false;
      });
      debugPrint('Login API Response Status: ${response.statusCode}');
      debugPrint('Login API Response Headers: ${response.headers}');
      debugPrint('Login API Response Body: ${response.body}');
      if (response.headers['content-type']?.contains('application/json') == true) {
        final jsonResponse = jsonDecode(response.body);
        debugPrint('Parsed Login API Response: $jsonResponse');
        if (jsonResponse['status'] == 'success' && response.statusCode >= 200 && response.statusCode < 300) {
          final prefs = await SharedPreferences.getInstance();
          final userId = jsonResponse['userId'].toString();
          await prefs.setString('user_id', userId);
          if (_rememberMe) {
            await prefs.setString('email', _emailController.text);
            await prefs.setString('password', _passwordController.text);
          }
          try {
            final userResponse = await http.get(
              Uri.parse('http://apis.nebo.co.ke/apis/user/$userId'),
              headers: {'Content-Type': 'application/json'},
            ).timeout(const Duration(seconds: 10));
            final userData = jsonDecode(userResponse.body);
            debugPrint('User API Response: $userData');
            if (userData['status'] == 'success') {
              final userName = userData['name'] ?? 'User';
              final selfiePath = userData['selfie_path'] ?? '';
              final email = userData['email'] ?? _emailController.text;
              final phone = userData['phone_number'] ?? '';
              await prefs.setString('user_name', userName);
              await prefs.setString('selfie_path', selfiePath);
              await prefs.setString('email', email);
              await prefs.setString('phone_number', phone);
            }
          } catch (userError) {
            debugPrint('Error fetching user data: $userError');
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login successful!')),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => graph.SavingsDashboard(userId: userId)),
          );
        } else {
          final errorMessage = _parseErrorMessage(response, fallbackMessage: 'Login failed. Please try again.');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
          if (errorMessage == 'Login failed. Please try again.' || response.statusCode >= 500) {
            _showFallbackLoginDialog(errorMessage);
          }
        }
      } else {
        final errorMessage = _parseErrorMessage(response, fallbackMessage: 'Login failed. Please try again.');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
        _showFallbackLoginDialog(errorMessage);
      }
    } catch (e, stackTrace) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error sending login request: $e');
      debugPrint('Stack trace: $stackTrace');
      String errorMessage;
      if (e is SocketException) {
        errorMessage = 'No internet connection. Please check your network.';
      } else if (e is TimeoutException) {
        errorMessage = 'Request timed out. Please try again.';
      } else {
        errorMessage = 'An error occurred during login. Please try again.';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
      _showFallbackLoginDialog(errorMessage);
    }
  }
  Future<void> _signInWithGoogle() async {
    if (!await checkInternetConnectivity()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection. Please check your network.')),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      await Firebase.initializeApp();
      final FirebaseAuth auth = FirebaseAuth.instance;
      UserCredential userCredential;
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email openid profile');
        userCredential = await auth.signInWithPopup(googleProvider);
      } else {
        final GoogleSignIn googleSignIn = GoogleSignIn(
          clientId: kIsWeb ? webClientId : null,
          scopes: ['email', 'openid', 'profile'],
        );
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          setState(() {
            _isLoading = false;
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google Sign-In was cancelled.')),
          );
          return;
        }
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await auth.signInWithCredential(credential);
      }
      final User? user = userCredential.user;
      if (user == null) {
        throw Exception('Google Sign-In failed: No user returned.');
      }
      final String? idToken = await user.getIdToken();
      if (idToken == null) {
        throw Exception('Authentication token is missing.');
      }
      final String email = user.email ?? '';
      final String name = user.displayName ?? 'Google User';
      final String? photoUrl = user.photoURL;
      debugPrint('Firebase Sign-In: Email: $email, Name: $name, PhotoURL: $photoUrl');
      final loginResponse = await http.post(
        Uri.parse('http://apis.nebo.co.ke/apis/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'google_id_token': idToken,
          'is_google_sign_in': true,
        }),
      ).timeout(const Duration(seconds: 30));
      debugPrint('Google Login API Response Status: ${loginResponse.statusCode}');
      debugPrint('Google Login API Response Body: ${loginResponse.body}');
      if (loginResponse.headers['content-type']?.contains('application/json') == true) {
        final jsonResponse = jsonDecode(loginResponse.body);
        debugPrint('Parsed Google Login API Response: $jsonResponse');
        if (jsonResponse['status'] == 'success') {
          final String backendUserId = jsonResponse['userId'].toString();
          final bool faceVerified = jsonResponse['faceVerified'] == true || jsonResponse['faceVerified'] == 1;
          debugPrint('Backend User ID: $backendUserId, Face Verified: $faceVerified');
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_id', backendUserId);
          Map<String, dynamic> userData = {};
          try {
            final userResponse = await http.get(
              Uri.parse('http://apis.nebo.co.ke/apis/user/$backendUserId'),
              headers: {'Content-Type': 'application/json'},
            ).timeout(const Duration(seconds: 10));
            debugPrint('User API Response Status: ${userResponse.statusCode}');
            debugPrint('User API Response Body: ${userResponse.body}');
            if (userResponse.statusCode == 200 && userResponse.headers['content-type']?.contains('application/json') == true) {
              userData = jsonDecode(userResponse.body);
              debugPrint('Parsed User API Response: $userData');
            } else {
              debugPrint('User API failed with status: ${userResponse.statusCode}');
              throw Exception('Failed to fetch user data.');
            }
          } catch (userError) {
            debugPrint('Error fetching user data: $userError');
          }
          await prefs.setString('user_name', userData['name']?.toString() ?? name);
          await prefs.setString('email', userData['email']?.toString() ?? email);
          await prefs.setString('phone_number', userData['phone_number']?.toString() ?? '');
          await prefs.setString('selfie_path', userData['selfie_path']?.toString() ?? photoUrl ?? '');
          if (faceVerified) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Google Sign-In successful!')),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => graph.SavingsDashboard(userId: backendUserId),
              ),
            );
          } else {
            if (!mounted) return;
            final registered = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (context) => Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: MediaQuery.of(context).size.height * 0.8,
                  child: SignUpScreen(
                    isGoogleSignIn: true,
                    googleName: name,
                    googleEmail: email,
                    googleIdToken: idToken,
                    googlePhotoUrl: photoUrl,
                  ),
                ),
              ),
            );
            if (registered == true && mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => graph.SavingsDashboard(userId: backendUserId),
                ),
              );
            }
          }
        } else if (jsonResponse['message'] == 'User not found') {
          debugPrint('User not found, showing SignUpScreen dialog');
          if (!mounted) return;
          final registered = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.8,
                child: SignUpScreen(
                  isGoogleSignIn: true,
                  googleName: name,
                  googleEmail: email,
                  googleIdToken: idToken,
                  googlePhotoUrl: photoUrl,
                ),
              ),
            ),
          );
          if (registered == true && mounted) {
            final prefs = await SharedPreferences.getInstance();
            final userId = prefs.getString('user_id') ?? 'default_user';
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => graph.SavingsDashboard(userId: userId),
              ),
            );
          }
        } else {
          final errorMessage = _parseErrorMessage(loginResponse, fallbackMessage: 'Google Sign-In failed. Please try again.');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      } else {
        final errorMessage = _parseErrorMessage(loginResponse, fallbackMessage: 'Google Sign-In failed. Please try again.');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Firebase Google Sign-In error: $e');
      debugPrint('Stack trace: $stackTrace');
      String errorMessage;
      if (e.toString().contains('cancelled')) {
        errorMessage = 'Google Sign-In was cancelled.';
      } else if (e is SocketException) {
        errorMessage = 'No internet connection. Please check your network.';
      } else if (e is TimeoutException) {
        errorMessage = 'Request timed out. Please try again.';
      } else {
        errorMessage = 'An error occurred during Google Sign-In. Please try again.';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  void _showFallbackLoginDialog(String errorMessage) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1F2937),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'Login Issue',
            style: TextStyle(
              color: Colors.white,
              fontSize: MediaQuery.of(context).size.width * 0.05,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Unable to log in: $errorMessage',
            style: TextStyle(
              color: Colors.grey[200],
              fontSize: MediaQuery.of(context).size.width * 0.035,
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                'Try Again',
                style: TextStyle(
                  color: const Color(0xFFFFC107),
                  fontSize: MediaQuery.of(context).size.width * 0.04,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _loginUser();
              },
            ),
            TextButton(
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: const Color(0xFFFFC107),
                  fontSize: MediaQuery.of(context).size.width * 0.04,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  void _showForgotPasswordDialog() {
    final forgotPasswordController = TextEditingController();
    bool isLoading = false;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1F2937),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text(
                'Forgot Password',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: screenWidth * 0.05,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter your email to receive a password reset link.',
                    style: TextStyle(
                      color: Colors.grey[200],
                      fontSize: screenWidth * 0.035,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: forgotPasswordController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF374151),
                      prefixIcon: Icon(Icons.email, color: Colors.grey[400]),
                      hintText: 'Enter your email',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: const Color(0xFFFFC107),
                      fontSize: screenWidth * 0.04,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Send Reset Link',
                          style: TextStyle(
                            color: const Color(0xFFFFC107),
                            fontSize: screenWidth * 0.04,
                          ),
                        ),
                  onPressed: isLoading
                      ? null
                      : () async {
                          final email = forgotPasswordController.text.trim();
                          if (email.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter your email')),
                            );
                            return;
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a valid email address')),
                            );
                            return;
                          }
                          setStateDialog(() {
                            isLoading = true;
                          });
                          await _requestPasswordReset(email);
                          if (mounted) {
                            setStateDialog(() {
                              isLoading = false;
                            });
                            Navigator.of(context).pop();
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }
  Future<void> _requestPasswordReset(String email) async {
    if (!await checkInternetConnectivity()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection. Please check your network.')),
      );
      return;
    }
    const String apiUrl = 'http://127.0.0.1/apis/api.php/forgot-password';
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
        }),
      ).timeout(const Duration(seconds: 15));
      debugPrint('Forgot Password API Response Status: ${response.statusCode}');
      debugPrint('Forgot Password API Response Body: ${response.body}');
      if (response.headers['content-type']?.contains('application/json') == true) {
        final jsonResponse = jsonDecode(response.body);
        debugPrint('Parsed Forgot Password API Response: $jsonResponse');
        if (jsonResponse['status'] == 'success' && response.statusCode >= 200 && response.statusCode < 300) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password reset link sent to your email.')),
          );
        } else {
          final errorMessage = _parseErrorMessage(response, fallbackMessage: 'Failed to send reset link. Please try again.');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      } else {
        final errorMessage = _parseErrorMessage(response, fallbackMessage: 'Failed to send reset link. Please try again.');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error sending forgot password request: $e');
      debugPrint('Stack trace: $stackTrace');
      String errorMessage;
      if (e is SocketException) {
        errorMessage = 'No internet connection. Please check your network.';
      } else if (e is TimeoutException) {
        errorMessage = 'Request timed out. Please try again.';
      } else {
        errorMessage = 'An error occurred while sending the reset link. Please try again.';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }
  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        return AlertDialog(
          backgroundColor: const Color(0xFF1F2937),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'Privacy Policy',
            style: TextStyle(
              color: Colors.white,
              fontSize: screenWidth * 0.05,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Text(
              '''
Haba na Haba Privacy Policy
Last Updated: August 15, 2025
1. Information We Collect
We collect personal information you provide, such as:
- Name, email, phone number, national ID, and date of birth.
- Selfie for identity verification.
- Google account details (if using Google Sign-In).
- Usage data (e.g., app interactions, device information).
2. How We Use Your Information
Your information is used to:
- Create and manage your account.
- Verify your identity for security and compliance.
- Provide personalized savings and financial services.
- Improve our app and services.
3. Data Sharing
We may share your data with:
- Service providers for verification and analytics.
- Regulatory authorities as required by law.
We do not sell your personal information.
4. Data Security
We use encryption and secure servers to protect your data. However, no system is completely secure, and you share information at your own risk.
5. Your Rights
You may:
- Access or update your personal information.
- Request deletion of your account (subject to legal obligations).
- Opt out of non-essential communications.
6. Contact Us
For questions, contact us at support@habanahaba.com.
This policy may be updated periodically. Continued use of the app constitutes acceptance of the updated policy.
              ''',
              style: TextStyle(
                color: Colors.grey[200],
                fontSize: screenWidth * 0.035,
              ),
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                'Close',
                style: TextStyle(
                  color: const Color(0xFFFFC107),
                  fontSize: screenWidth * 0.04,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  void _showTermsOfServiceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        return AlertDialog(
          backgroundColor: const Color(0xFF1F2937),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'Terms of Service',
            style: TextStyle(
              color: Colors.white,
              fontSize: screenWidth * 0.05,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Text(
              '''
Haba na Haba Terms of Service
Last Updated: August 15, 2025
1. Acceptance of Terms
By using Haba na Haba, you agree to these Terms of Service. If you do not agree, please do not use the app.
2. Account Responsibilities
- You must provide accurate information during registration.
- Keep your password secure and do not share it.
- You are responsible for all activities under your account.
3. Acceptable Use
You agree not to:
- Use the app for illegal activities.
- Attempt to hack or disrupt the app.
- Submit false or misleading information.
4. Service Limitations
- The app is provided "as is" with no warranties.
- We may suspend or terminate your access for violations of these terms.
- Service availability may vary due to maintenance or technical issues.
5. Termination
We may terminate your account for:
- Breach of these terms.
- Suspicious or fraudulent activity.
You may delete your account at any time.
6. Limitation of Liability
Haba na Haba is not liable for:
- Losses due to unauthorized access to your account.
- Service interruptions or data loss.
- Financial decisions based on app features.
7. Contact Us
For support, contact support@habanahaba.com.
We may update these terms periodically. Continued use constitutes acceptance of the updated terms.
              ''',
              style: TextStyle(
                color: Colors.grey[200],
                fontSize: screenWidth * 0.035,
              ),
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                'Close',
                style: TextStyle(
                  color: const Color(0xFFFFC107),
                  fontSize: screenWidth * 0.04,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: const Color(0xFF1F2937),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Haba na Haba',
                        style: TextStyle(
                          fontSize: screenWidth * 0.06,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Welcome back! Please sign in to continue',
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildTextField(
                      label: 'Email',
                      icon: Icons.email,
                      isPassword: false,
                      controller: _emailController,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Password',
                      icon: Icons.lock,
                      isPassword: true,
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      onToggleObscure: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (value) {
                                setState(() {
                                  _rememberMe = value ?? false;
                                });
                              },
                              activeColor: Colors.grey[800],
                              checkColor: Colors.white,
                            ),
                            Text(
                              'Remember me',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: screenWidth * 0.035,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: _showForgotPasswordDialog,
                          child: Text(
                            'Forgot password?',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: screenWidth * 0.035,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFC107),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _isLoading ? null : _loginUser,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                ),
                              )
                            : Text(
                                'Sign In',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: screenWidth * 0.04,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Or sign in with',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: screenWidth * 0.035,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Image.asset(
                          'assets/google.png',
                          width: 28,
                          height: 28,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('Google logo loading error: $error');
                            return const Icon(Icons.error, color: Colors.white, size: 28);
                          },
                        ),
                        label: Text(
                          'Continue with Google',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: screenWidth * 0.04,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF374151),
                          side: BorderSide(color: Colors.grey[600]!),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _isLoading ? null : _signInWithGoogle,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          debugPrint('Navigating to SignUpScreen');
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignUpScreen(
                                isGoogleSignIn: false,
                              ),
                            ),
                          );
                        },
                        child: Text(
                          "Don't have an account? Create account",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: screenWidth * 0.035,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _showPrivacyPolicyDialog,
                          child: Text(
                            'Privacy Policy',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: screenWidth * 0.035,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '|',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: screenWidth * 0.035,
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _showTermsOfServiceDialog,
                          child: Text(
                            'Terms of Service',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: screenWidth * 0.035,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildTextField({
    required String label,
    required IconData icon,
    required bool isPassword,
    TextEditingController? controller,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: MediaQuery.of(context).size.width * 0.035,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword ? obscureText : false,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF374151),
            prefixIcon: Icon(icon, color: Colors.grey[400]),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey[400],
                    ),
                    onPressed: onToggleObscure,
                  )
                : null,
            hintText: 'Enter your $label',
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}