import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' show File, SocketException;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'graph.dart' as graph;

// Google Sign-In Client ID for Web
const String webClientId = '825042983512-b3eea0b1eg88hvqks2c7d0i989tj79qf.apps.googleusercontent.com';

// Check internet connectivity without connectivity_plus
Future<bool> checkInternetConnectivity() async {
  try {
    final response = await http.get(Uri.parse('http://8.8.8.8')).timeout(const Duration(seconds: 5));
    return response.statusCode == 200;
  } catch (e) {
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
      home: const SignInScreen(),
    );
  }
}

// Sign Up Screen
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
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
  File? _selfieImage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isSelfieUploaded = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickSelfie() async {
    var cameraStatus = await Permission.camera.request();
    var photosStatus = await Permission.photos.request();
    if (cameraStatus.isGranted || photosStatus.isGranted) {
      final pickedFile = await _picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        setState(() {
          _selfieImage = File(pickedFile.path);
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

  Future<void> _registerUser() async {
    // Check connectivity
    if (!await checkInternetConnectivity()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection. Please check your network.')),
      );
      return;
    }

    // Input validation
    if (_fullNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _nationalIdController.text.isEmpty ||
        _dobController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
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

    if (_passwordController.text != _confirmPasswordController.text) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    if (_selfieImage == null && !_isSelfieUploaded) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a selfie')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://apis.gnmprimesource.co.ke/apis/register'),
      );

      request.fields['full_name'] = _fullNameController.text;
      request.fields['email'] = _emailController.text;
      request.fields['phone_number'] = _phoneController.text;
      request.fields['national_id'] = _nationalIdController.text;
      request.fields['date_of_birth'] = _dobController.text;
      request.fields['password'] = _passwordController.text;

      if (_selfieImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('selfie', _selfieImage!.path),
        );
      }

      final response = await request.send().timeout(const Duration(seconds: 30));
      final responseData = await response.stream.bytesToString();
      final jsonResponse = jsonDecode(responseData);
      debugPrint('Register API Response: $jsonResponse');

      setState(() {
        _isLoading = false;
      });

      if (jsonResponse['status'] == 'success') {
        final prefs = await SharedPreferences.getInstance();
        final userId = jsonResponse['userId'].toString();
        await prefs.setString('user_id', userId);
        await prefs.setString('user_name', _fullNameController.text);
        await prefs.setString('email', _emailController.text);
        await prefs.setString('phone_number', _phoneController.text);
        await prefs.setString('selfie_path', jsonResponse['selfie_path'] ?? '');

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful!')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SignInScreen()),
        );
      } else {
        String errorMessage;
        switch (jsonResponse['message']) {
          case 'Email already exists':
            errorMessage = 'This email is already registered.';
            break;
          case 'Invalid email format':
            errorMessage = 'Please enter a valid email address.';
            break;
          case 'Invalid phone number':
            errorMessage = 'Please enter a valid phone number.';
            break;
          case 'Invalid date of birth':
            errorMessage = 'Please enter a valid date of birth (YYYY-MM-DD).';
            break;
          case 'Weak password':
            errorMessage = 'Password must be at least 8 characters long.';
            break;
          default:
            errorMessage = jsonResponse['message']?.toString() ?? 'An unknown error occurred.';
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $errorMessage')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error sending registration request: $e');
      if (e is SocketException) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error: Please check your internet connection')),
        );
      } else if (e is TimeoutException) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request timed out. Server might be slow or unreachable.')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect to the server: $e')),
        );
      }
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
                        'Please fill in the details to sign up',
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildTextField(
                      label: 'Full Name',
                      icon: Icons.person,
                      controller: _fullNameController,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Email',
                      icon: Icons.email,
                      controller: _emailController,
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
                    const SizedBox(height: 16),
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
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const SignInScreen()),
                          );
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

  Widget _buildTopNavigationBar() {
    return Padding(
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
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    TextEditingController? controller,
    bool isPassword = false,
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

// Sign In Screen
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
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
    // Check connectivity
    if (!await checkInternetConnectivity()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection. Please check your network.')),
      );
      return;
    }

    // Input validation
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

    const String apiUrl = 'http://apis.gnmprimesource.co.ke/apis/login/';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      ).timeout(const Duration(seconds: 15));

      setState(() {
        _isLoading = false;
      });

      final jsonResponse = jsonDecode(response.body);
      debugPrint('Login API Response: $jsonResponse');

      if (jsonResponse['status'] == 'success') {
        final prefs = await SharedPreferences.getInstance();
        final userId = jsonResponse['userId'].toString();
        await prefs.setString('user_id', userId);

        if (_rememberMe) {
          await prefs.setString('email', _emailController.text);
          await prefs.setString('password', _passwordController.text);
        }

        try {
          final userResponse = await http.get(
            Uri.parse('http://apis.gnmprimesource.co.ke/apis/user/$userId'),
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
        String errorMessage;
        switch (jsonResponse['message']) {
          case 'Email and password required':
            errorMessage = 'Please enter both email and password.';
            break;
          case 'User not found':
            errorMessage = 'No account found with this email.';
            break;
          case 'Invalid password':
            errorMessage = 'Incorrect password. Please try again.';
            break;
          default:
            if (jsonResponse['message'].toString().startsWith('AML check failed')) {
              errorMessage = 'Login denied due to AML restrictions.';
            } else {
              errorMessage = jsonResponse['message']?.toString() ?? 'An unknown error occurred.';
            }
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $errorMessage')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error sending login request: $e');
      if (e is SocketException) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error: Please check your internet connection')),
        );
      } else if (e is TimeoutException) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request timed out. Server might be slow or unreachable.')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to connect to the server. Try again or use fallback login.'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Try Again',
              onPressed: _loginUser,
            ),
          ),
        );
      }
      if (!mounted) return;
      _showFallbackLoginDialog();
    }
  }

  Future<void> _signInWithGoogle() async {
    // Check connectivity
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
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email'],
        clientId: kIsWeb ? webClientId : null,
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google Sign-In cancelled');
      }

      // Handle scope authorization for web
      if (kIsWeb) {
        bool isAuthorized = await googleSignIn.canAccessScopes(['email']);
        if (!isAuthorized) {
          await googleSignIn.requestScopes(['email']);
        }
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String email = googleUser.email;
      final String name = googleUser.displayName ?? 'Google User';
      final String? photoUrl = googleUser.photoUrl;
      final String userId = googleUser.id;

      // Check if user exists in backend
      try {
        final loginResponse = await http.post(
          Uri.parse('http://apis.gnmprimesource.co.ke/apis/login/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'google_id_token': googleAuth.idToken,
            'is_google_sign_in': true,
          }),
        ).timeout(const Duration(seconds: 30));

        final jsonResponse = jsonDecode(loginResponse.body);
        debugPrint('Google Login API Response: $jsonResponse');

        if (jsonResponse['status'] == 'success') {
          // User exists
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_id', userId);
          await prefs.setString('user_name', name);
          await prefs.setString('email', email);
          await prefs.setString('phone_number', '');
          await prefs.setString('selfie_path', photoUrl ?? '');

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google Sign-In successful!')),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => graph.SavingsDashboard(userId: userId)),
          );
        } else if (jsonResponse['message'] == 'User not found') {
          // Prompt for additional details and register
          final additionalDetails = await _promptForAdditionalDetails(context, name, email);
          if (additionalDetails == null) {
            throw Exception('Registration cancelled');
          }

          final registerRequest = http.MultipartRequest(
            'POST',
            Uri.parse('http://apis.gnmprimesource.co.ke/apis/register'),
          );
          registerRequest.fields['full_name'] = additionalDetails['name']!;
          registerRequest.fields['email'] = email;
          registerRequest.fields['phone_number'] = additionalDetails['phone']!;
          registerRequest.fields['national_id'] = additionalDetails['national_id']!;
          registerRequest.fields['date_of_birth'] = additionalDetails['dob']!;
          registerRequest.fields['password'] = '';
          registerRequest.fields['google_id_token'] = googleAuth.idToken!;

          final registerResponse = await registerRequest.send().timeout(const Duration(seconds: 30));
          final registerData = await registerResponse.stream.bytesToString();
          final registerJson = jsonDecode(registerData);
          debugPrint('Google Register API Response: $registerJson');

          if (registerJson['status'] == 'success') {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_id', userId);
            await prefs.setString('user_name', name);
            await prefs.setString('email', email);
            await prefs.setString('phone_number', additionalDetails['phone']!);
            await prefs.setString('selfie_path', photoUrl ?? '');

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Google Sign-In and registration successful!')),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => graph.SavingsDashboard(userId: userId)),
            );
          } else {
            throw Exception('Registration failed: ${registerJson['message']}');
          }
        } else {
          throw Exception('Login failed: ${jsonResponse['message']}');
        }
      } catch (e) {
        debugPrint('Error with backend integration: $e');
        throw Exception('Backend integration failed: $e');
      }
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      String errorMessage = 'Google Sign-In failed';
      if (e.toString().contains('ApiException: 10')) {
        errorMessage = 'Invalid client ID or SHA-1 fingerprint';
      } else if (e.toString().contains('network_error')) {
        errorMessage = 'Network error during Google Sign-In';
      } else if (e.toString().contains('cancelled')) {
        errorMessage = 'Google Sign-In was cancelled';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$errorMessage: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, String>?> _promptForAdditionalDetails(BuildContext context, String name, String email) async {
    final phoneController = TextEditingController();
    final nationalIdController = TextEditingController();
    final dobController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Registration'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number (e.g., 0700123456)'),
              ),
              TextField(
                controller: nationalIdController,
                decoration: const InputDecoration(labelText: 'National ID'),
              ),
              TextField(
                controller: dobController,
                decoration: const InputDecoration(labelText: 'Date of Birth (YYYY-MM-DD)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (phoneController.text.isEmpty ||
                  nationalIdController.text.isEmpty ||
                  dobController.text.isEmpty) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill in all fields')),
                );
                return;
              }
              Navigator.pop(context, {
                'name': name,
                'phone': phoneController.text,
                'national_id': nationalIdController.text,
                'dob': dobController.text,
              });
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    phoneController.dispose();
    nationalIdController.dispose();
    dobController.dispose();
    return result;
  }

  void _showFallbackLoginDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Server Connection Issue'),
          content: const Text('We\'re having trouble connecting to our servers. Would you like to:'),
          actions: [
            TextButton(
              child: const Text('Try Again'),
              onPressed: () {
                Navigator.of(context).pop();
                _loginUser();
              },
            ),
            TextButton(
              child: const Text('Demo Mode'),
              onPressed: () {
                Navigator.of(context).pop();
                _mockLoginUser();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _mockLoginUser() async {
    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    const String demoUserId = '12345';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', demoUserId);
    await prefs.setString('user_name', 'Demo User');
    await prefs.setString('email', 'demo@example.com');
    await prefs.setString('phone_number', '0700123456');
    await prefs.setString('selfie_path', '');
    await prefs.setString('is_demo_mode', 'true');

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logged in with demo account'),
        duration: Duration(seconds: 3),
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => graph.SavingsDashboard(userId: demoUserId)),
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
                          onTap: () {
                            debugPrint('Forget password tapped');
                          },
                          child: Text(
                            'Forget password?',
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
                        icon: const Icon(Icons.g_mobiledata, color: Colors.white, size: 30),
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SignUpScreen()),
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
                          onTap: () {
                            debugPrint('Privacy Policy tapped');
                          },
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
                          onTap: () {
                            debugPrint('Terms of Service tapped');
                          },
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

  Widget _buildTopNavigationBar() {
    return Padding(
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
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required bool isPassword,
    TextEditingController? controller,
    bool readOnly = false,
    VoidCallback? onTap,
    String? hintText,
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
          obscureText: isPassword ? _obscurePassword : false,
          readOnly: readOnly,
          onTap: onTap,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF374151),
            prefixIcon: Icon(icon, color: Colors.grey[400]),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey[400],
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  )
                : null,
            hintText: hintText ?? 'Enter your $label',
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
