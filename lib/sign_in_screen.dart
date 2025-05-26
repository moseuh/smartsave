import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

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
    setState(() {
      _isLoading = true;
    });

    const String apiUrl = 'https://apis.gnmprimesource.co.ke/api/login/';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'is_google_sign_in': false,
        }),
      ).timeout(const Duration(seconds: 15));

      final jsonResponse = jsonDecode(response.body);
      debugPrint('Login API Response: $jsonResponse');

      if (jsonResponse['status'] == 'success' || jsonResponse['status'] == 'warning') {
        final prefs = await SharedPreferences.getInstance();
        final userId = jsonResponse['userId'].toString();
        await prefs.setString('user_id', userId);
        await prefs.setString('email', _emailController.text.trim());
        await prefs.setString('user_name', '');
        await prefs.setString('phone_number', '');
        await prefs.setString('selfie_path', '');

        if (_rememberMe) {
          await prefs.setString('email', _emailController.text.trim());
          await prefs.setString('password', _passwordController.text);
        } else {
          await prefs.remove('email');
          await prefs.remove('password');
        }

        try {
          final userResponse = await http.get(
            Uri.parse('https://apis.gnmprimesource.co.ke/api/user/$userId'),
            headers: {'Content-Type': 'application/json'},
          ).timeout(const Duration(seconds: 10));

          final userData = jsonDecode(userResponse.body);
          debugPrint('User API Response: $userData');

          if (userData['status'] == 'success') {
            await prefs.setString('user_name', userData['name'] ?? 'User');
            await prefs.setString('selfie_path', userData['selfie_path'] ?? '');
            await prefs.setString('email', userData['email'] ?? _emailController.text.trim());
            await prefs.setString('phone_number', userData['phone_number'] ?? '');
          }
        } catch (userError) {
          debugPrint('Error fetching user data: $userError');
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login successful!')),
        );
        Navigator.pushReplacementNamed(context, '/home', arguments: userId);
      } else {
        throw Exception(jsonResponse['message'] ?? 'Login failed');
      }
    } catch (e, stackTrace) {
      debugPrint('Error sending login request: $e\n$stackTrace');
      String errorMessage;
      if (e.toString().contains('Email and password required')) {
        errorMessage = 'Please enter both email and password.';
      } else if (e.toString().contains('User not found')) {
        errorMessage = 'No account found with this email.';
      } else if (e.toString().contains('Invalid password')) {
        errorMessage = 'Incorrect password. Please try again.';
      } else if (e.toString().contains('AML check failed')) {
        errorMessage = 'Login denied due to AML restrictions.';
      } else if (e.toString().contains('network error')) {
        errorMessage = 'Network error: Please check your internet connection.';
      } else if (e is TimeoutException) {
        errorMessage = 'Request timed out. Server might be slow or unreachable.';
      } else {
        errorMessage = 'Login failed: ${e.toString()}';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          action: SnackBarAction(
            label: 'Try Again',
            onPressed: _loginUser,
          ),
        ),
      );
      _showFallbackDialog();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: kIsWeb ? '825042983512-b3eea0b1eg88hvqks2c7d0i989tj79qf.apps.googleusercontent.com' : null,
        scopes: [
          'email',
          'profile',
          'openid',
          'https://www.googleapis.com/auth/userinfo.email',
          'https://www.googleapis.com/auth/userinfo.profile',
        ],
        forceCodeForRefreshToken: true,
      );

      // Sign out to ensure fresh authentication
      await googleSignIn.signOut();
      debugPrint('Signed out from Google');

      GoogleSignInAccount? googleUser;
      GoogleSignInAuthentication? googleAuth;
      int retryCount = 0;
      const maxRetries = 2;

      // Retry logic for ID token
      while (retryCount < maxRetries) {
        googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          throw Exception('Google Sign-In cancelled by user');
        }

        debugPrint('Google User: ${googleUser.email}, ${googleUser.id}');
        googleAuth = await googleUser.authentication;
        if (googleAuth != null) {
          debugPrint('Access Token: ${googleAuth.accessToken}');
          debugPrint('ID Token: ${googleAuth.idToken}');
        } else {
          debugPrint('Google authentication failed, googleAuth is null');
        }

        if (googleAuth?.idToken != null) {
          break; // ID token received, exit retry loop
        }

        debugPrint('ID token is null, retrying (${retryCount + 1}/$maxRetries)...');
        await googleSignIn.signOut();
        retryCount++;
      }

      if (googleAuth == null || googleAuth.idToken == null || googleAuth.accessToken == null) {
        throw Exception('Google Sign-In failed: No ID token or access token received after $maxRetries retries');
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null || googleUser == null) {
        throw Exception('Firebase authentication failed: No user returned');
      }

      debugPrint('Firebase User: ${firebaseUser.email}, ${firebaseUser.uid}');

      final String email = firebaseUser.email ?? googleUser.email;
      final String name = firebaseUser.displayName ?? googleUser.displayName ?? 'Google User';
      final String? photoUrl = firebaseUser.photoURL ?? googleUser.photoUrl;

      final loginResponse = await http.post(
        Uri.parse('https://apis.gnmprimesource.co.ke/api/login/'),
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
        final prefs = await SharedPreferences.getInstance();
        final userId = jsonResponse['userId'].toString();
        await prefs.setString('user_id', userId);
        await prefs.setString('user_name', name);
        await prefs.setString('email', email);
        await prefs.setString('phone_number', '');
        await prefs.setString('selfie_path', photoUrl ?? '');

        if (_rememberMe) {
          await prefs.setString('email', email);
        } else {
          await prefs.remove('email');
          await prefs.remove('password');
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Sign-In successful!')),
        );
        Navigator.pushReplacementNamed(context, '/home', arguments: userId);
      } else if (jsonResponse['message'] == 'User not found') {
        if (!mounted) return;
        final additionalDetails = await _promptForAdditionalDetails(context, name, email);
        if (additionalDetails == null) {
          return;
        }

        var request = http.MultipartRequest(
          'POST',
          Uri.parse('https://apis.gnmprimesource.co.ke/api/register'),
        );
        request.fields['full_name'] = additionalDetails['name']!;
        request.fields['email'] = email;
        request.fields['phone_number'] = additionalDetails['phone']!;
        request.fields['national_id'] = additionalDetails['national_id']!;
        request.fields['date_of_birth'] = additionalDetails['dob']!;
        request.fields['google_id_token'] = googleAuth.idToken!;
        request.fields['is_google_sign_in'] = 'true';

        if (additionalDetails['selfie'] != null) {
          final selfieFile = additionalDetails['selfie'] as XFile;
          if (kIsWeb) {
            final bytes = await selfieFile.readAsBytes();
            request.files.add(http.MultipartFile.fromBytes('selfie', bytes, filename: selfieFile.name));
          } else {
            request.files.add(await http.MultipartFile.fromPath('selfie', selfieFile.path));
          }
        }
        if (additionalDetails['id_document'] != null) {
          final idDocumentFile = additionalDetails['id_document'] as XFile;
          if (kIsWeb) {
            final bytes = await idDocumentFile.readAsBytes();
            request.files.add(http.MultipartFile.fromBytes('id_document', bytes, filename: idDocumentFile.name));
          } else {
            request.files.add(await http.MultipartFile.fromPath('id_document', idDocumentFile.path));
          }
        }

        final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
        final registerData = await streamedResponse.stream.bytesToString();
        final registerJson = jsonDecode(registerData);
        debugPrint('Google Register API Response: $registerJson');

        if (registerJson['status'] == 'success') {
          final prefs = await SharedPreferences.getInstance();
          final userId = registerJson['userId'].toString();
          await prefs.setString('user_id', userId);
          await prefs.setString('user_name', name);
          await prefs.setString('email', email);
          await prefs.setString('phone_number', additionalDetails['phone']!);
          await prefs.setString('selfie_path', photoUrl ?? '');

          if (_rememberMe) {
            await prefs.setString('email', email);
          } else {
            await prefs.remove('email');
            await prefs.remove('password');
          }

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google Sign-In and registration successful!')),
          );
          Navigator.pushReplacementNamed(context, '/home', arguments: userId);
        } else {
          throw Exception('Registration failed: ${registerJson['message']}');
        }
      } else {
        throw Exception('Google login failed: ${jsonResponse['message']}');
      }
    } catch (e, stackTrace) {
      debugPrint('Google Sign-In error: $e\n$stackTrace');
      String errorMessage;
      if (e.toString().contains('ApiException: 10')) {
        errorMessage = 'Invalid client ID or configuration. Please check Firebase and Google Cloud Console.';
      } else if (e.toString().contains('network_error')) {
        errorMessage = 'Network error during Google Sign-In. Please check your internet connection.';
      } else if (e.toString().contains('cancelled')) {
        errorMessage = 'Google Sign-In was cancelled by the user.';
      } else if (e.toString().contains('No ID token')) {
        errorMessage = 'Failed to retrieve ID token. Please ensure Google Sign-In is configured correctly.';
      } else {
        errorMessage = 'Google Sign-In failed: ${e.toString()}';
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

  Future<Map<String, dynamic>?> _promptForAdditionalDetails(BuildContext context, String name, String email) async {
    final phoneController = TextEditingController();
    final nationalIdController = TextEditingController();
    final dobController = TextEditingController();
    XFile? selfieFile;
    XFile? idDocumentFile;
    final ImagePicker picker = ImagePicker();

    Future<void> pickSelfie() async {
      PermissionStatus status;
      if (kIsWeb) {
        status = await Permission.photos.request();
      } else {
        status = await Permission.camera.request();
      }
      if (status.isGranted) {
        final pickedFile = await picker.pickImage(source: kIsWeb ? ImageSource.gallery : ImageSource.camera);
        if (pickedFile != null) {
          selfieFile = pickedFile;
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera or photos permission denied')),
        );
      }
    }

    Future<void> pickIdDocument() async {
      final status = await Permission.photos.request();
      if (status.isGranted) {
        final pickedFile = await picker.pickImage(source: ImageSource.gallery);
        if (pickedFile != null) {
          idDocumentFile = pickedFile;
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photos permission denied')),
        );
      }
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Complete Google Sign-In'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number (e.g., +254700123456)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nationalIdController,
                    decoration: const InputDecoration(
                      labelText: 'National ID (7-8 digits)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dobController,
                    decoration: const InputDecoration(
                      labelText: 'Date of Birth (YYYY-MM-DD)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.datetime,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      await pickSelfie();
                      setDialogState(() {});
                    },
                    child: Text(selfieFile == null ? 'Upload Selfie (Optional)' : 'Selfie Uploaded'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      await pickIdDocument();
                      setDialogState(() {});
                    },
                    child: Text(idDocumentFile == null ? 'Upload ID Document (Optional)' : 'ID Document Uploaded'),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (phoneController.text.isEmpty || nationalIdController.text.isEmpty || dobController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide phone number, national ID, and date of birth')),
                );
                return;
              }
              if (!RegExp(r'^\+254[0-9]{9}$').hasMatch(phoneController.text)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Phone number must be in +254XXXXXXXXX format')),
                );
                return;
              }
              if (!RegExp(r'^\d{7,8}$').hasMatch(nationalIdController.text)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('National ID must be 7-8 digits')),
                );
                return;
              }
              if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dobController.text)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Date of birth must be in YYYY-MM-DD format')),
                );
                return;
              }
              Navigator.pop(context, {
                'name': name,
                'phone': phoneController.text,
                'national_id': nationalIdController.text,
                'dob': dobController.text,
                'selfie': selfieFile,
                'id_document': idDocumentFile,
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

  void _showFallbackDialog() {
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
    await prefs.setString('phone_number', '+254700123456');
    await prefs.setString('selfie_path', '');
    await prefs.setString('is_demo_mode', 'true');

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logged in with demo account'),
        duration: Duration(seconds: 3),
      ),
    );
    Navigator.pushReplacementNamed(context, '/home', arguments: demoUserId);
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

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

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
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isSelfieUploaded = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickSelfie() async {
    PermissionStatus status;
    if (kIsWeb) {
      status = await Permission.photos.request();
    } else {
      status = await Permission.camera.request();
    }
    if (status.isGranted) {
      final pickedFile = await _picker.pickImage(source: kIsWeb ? ImageSource.gallery : ImageSource.camera);
      if (pickedFile != null && mounted) {
        setState(() {
          _selfieImage = pickedFile;
          _isSelfieUploaded = true;
        });
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera or photos permission denied')),
      );
    }
  }

  Future<void> _registerUser() async {
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
        Uri.parse('https://apis.gnmprimesource.co.ke/api/register'),
      );

      request.fields['full_name'] = _fullNameController.text;
      request.fields['email'] = _emailController.text;
      request.fields['phone_number'] = _phoneController.text;
      request.fields['national_id'] = _nationalIdController.text;
      request.fields['date_of_birth'] = _dobController.text;
      request.fields['password'] = _passwordController.text;

      if (_selfieImage != null) {
        if (kIsWeb) {
          final bytes = await _selfieImage!.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes('selfie', bytes, filename: _selfieImage!.name));
        } else {
          request.files.add(await http.MultipartFile.fromPath('selfie', _selfieImage!.path));
        }
      }

      final response = await request.send().timeout(const Duration(seconds: 30));
      final responseData = await response.stream.bytesToString();
      final jsonResponse = jsonDecode(responseData);
      debugPrint('Register API Response: $jsonResponse');

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
        Navigator.pushReplacementNamed(context, '/sign_in');
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
    } catch (e, stackTrace) {
      debugPrint('Error sending registration request: $e\n$stackTrace');
      String errorMessage;
      if (e.toString().contains('network error')) {
        errorMessage = 'Network error: Please check your internet connection.';
      } else if (e is TimeoutException) {
        errorMessage = 'Request timed out. Server might be slow or unreachable.';
      } else {
        errorMessage = 'Registration failed: ${e.toString()}';
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