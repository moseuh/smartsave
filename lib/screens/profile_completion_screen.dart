import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../constants/app_theme.dart';
import '../constants/app_constants.dart';
import '../widgets/graph.dart' as graph;

/// Profile completion flow - Step-by-step KYC after login
class ProfileCompletionScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String userEmail;
  final String? userPhone;

  const ProfileCompletionScreen({
    Key? key,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.userPhone,
  }) : super(key: key);

  @override
  State<ProfileCompletionScreen> createState() => _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  bool _isLoading = false;
  bool _loadingProfile = true;

  // Track what fields are already filled
  bool _hasNationalId = false;
  bool _hasDob = false;
  bool _hasSelfie = false;
  bool _hasIdDocument = false;

  // Form controllers
  final _dobController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _phoneController = TextEditingController();
  DateTime? _selectedDate;
  File? _selfieImage;
  File? _idDocumentImage;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _fetchExistingProfile();
  }

  Future<void> _fetchExistingProfile() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/user-details/${widget.userId}'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final userData = data['data'];
          
          // Check what fields already exist (not placeholders)
          final nationalId = userData['national_id']?.toString() ?? '';
          final dob = (userData['date_of_birth'] ?? '').toString();
          final selfie = userData['selfie_path']?.toString() ?? '';
          final idDoc = (userData['id_document_path'] ?? userData['id_back_path'] ?? '').toString();
          
          final hasNationalId = nationalId.isNotEmpty && nationalId != 'PENDING';
          final hasDob = dob.isNotEmpty && dob != '1990-01-01';
          final hasSelfie = selfie.isNotEmpty;
          final hasIdDocument = idDoc.isNotEmpty;
          
          // Skip to dashboard if user has completed the basics (national ID + DOB)
          // Selfie and ID doc are optional — don't block dashboard access
          if (hasNationalId && hasDob && mounted) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('profile_completed', true);

            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => graph.SavingsDashboard(userId: widget.userId),
              ),
            );
            return;
          }
          
          setState(() {
            _hasNationalId = hasNationalId;
            _hasDob = hasDob;
            _hasSelfie = hasSelfie;
            _hasIdDocument = hasIdDocument;
            _loadingProfile = false;
          });
        }
      }
    } catch (e) {
      setState(() => _loadingProfile = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFF5BB1B), // Gold
              onPrimary: Colors.black,
              surface: Color(0xFF374151),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _dobController.dispose();
    _nationalIdController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isSelfie) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        if (isSelfie) {
          _selfieImage = File(pickedFile.path);
        } else {
          _idDocumentImage = File(pickedFile.path);
        }
      });
    }
  }

  Future<void> _submitProfile() async {
    setState(() => _isLoading = true);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConstants.apiBaseUrl}/complete-profile'),
      );

      request.fields['userId'] = widget.userId;
      
      // Only send fields that need to be updated
      if (!_hasNationalId && _nationalIdController.text.isNotEmpty) {
        request.fields['national_id'] = _nationalIdController.text;
      }
      
      if (!_hasDob && _dobController.text.isNotEmpty) {
        request.fields['date_of_birth'] = _dobController.text;
      }
      
      if (widget.userPhone != null) {
        request.fields['phone_number'] = widget.userPhone!;
      } else if (_phoneController.text.isNotEmpty) {
        request.fields['phone_number'] = _phoneController.text;
      }

      if (!_hasSelfie && _selfieImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('selfie_image', _selfieImage!.path),
        );
      }

      if (!_hasIdDocument && _idDocumentImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('id_document_image', _idDocumentImage!.path),
        );
      }

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonResponse = jsonDecode(responseData);

      if (response.statusCode == 200 && jsonResponse['status'] == 'success') {
        // Mark profile as complete
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('profile_completed', true);

        if (mounted) {
          // Navigate to dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => graph.SavingsDashboard(userId: widget.userId),
            ),
          );
        }
      } else {
        _showError(jsonResponse['message'] ?? 'Profile completion failed');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _nextStep() {
    if (_currentStep < 2) {
      _animationController.reset();
      setState(() => _currentStep++);
      _animationController.forward();
    } else {
      _submitProfile();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _animationController.reset();
      setState(() => _currentStep--);
      _animationController.forward();
    }
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        // Validate only fields that are not already filled
        bool nationalIdValid = _hasNationalId || _nationalIdController.text.trim().length >= 6;
        bool dobValid = _hasDob || (_dobController.text.isNotEmpty && _selectedDate != null);
        
        final phone = widget.userPhone ?? _phoneController.text.trim();
        bool phoneValid = phone.isNotEmpty && phone.length >= 12;
        
        return nationalIdValid && dobValid && phoneValid;
      case 1:
        // Selfie step - skip if already uploaded
        return _hasSelfie || _selfieImage != null || true; // Allow skip
      case 2:
        // ID document step - skip if already uploaded
        return _hasIdDocument || _idDocumentImage != null || true; // Allow skip
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildProgressIndicator(),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppTheme.cardLight,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildStepContent(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Complete Your Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Skip to dashboard
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => graph.SavingsDashboard(userId: widget.userId),
                    ),
                  );
                },
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Hi ${widget.userName}! Let\'s verify your identity',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;

          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: isCompleted || isActive
                    ? Colors.white
                    : Colors.white.withOpacity(0.3),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildBasicInfoStep();
      case 1:
        return _buildSelfieStep();
      case 2:
        return _buildIdDocumentStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _buildStepTitle('Personal Information', 'Step 1 of 3'),
          const SizedBox(height: 32),
          // Only show National ID if not already captured
          if (!_hasNationalId) ...[
            _buildTextField(
              controller: _nationalIdController,
              label: 'National ID / Passport',
              icon: Icons.badge_outlined,
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 20),
          ],
          // Only show DOB if not already captured
          if (!_hasDob) ...[
            GestureDetector(
              onTap: () => _selectDate(context),
              child: AbsorbPointer(
                child: _buildTextField(
                  controller: _dobController,
                  label: 'Date of Birth',
                  icon: Icons.calendar_today_outlined,
                  keyboardType: TextInputType.none,
                  hint: 'Tap to select date',
                  readOnly: true,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          // Only show phone field if not already captured during signup
          if (widget.userPhone == null) ...[
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.backgroundLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IntlPhoneField(
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.only(left: 12, top: 0, bottom: 16),
                ),
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                dropdownTextStyle: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                initialCountryCode: 'KE',
                disableLengthCheck: true,
                showDropdownIcon: false,
                flagsButtonPadding: const EdgeInsets.only(left: 8, right: 4),
                onChanged: (phone) {
                  setState(() {
                    _phoneController.text = phone.completeNumber;
                  });
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildSelfieStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _buildStepTitle('Take a Selfie', 'Step 2 of 3'),
          const SizedBox(height: 32),
          if (_hasSelfie) ...[
            const Center(
              child: Column(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFFF5BB1B), size: 64),
                  SizedBox(height: 16),
                  Text(
                    'Selfie already uploaded',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ] else ...[
            Center(
              child: GestureDetector(
                onTap: () => _pickImage(true),
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundLight,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: AppTheme.primaryColor,
                      width: 3,
                    ),
                    image: _selfieImage != null
                        ? DecorationImage(
                            image: FileImage(_selfieImage!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _selfieImage == null
                      ? const Icon(
                          Icons.camera_alt,
                          size: 60,
                          color: AppTheme.primaryColor,
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'For security purposes, please take a clear selfie. Make sure your face is well-lit and clearly visible.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 40),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildIdDocumentStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _buildStepTitle('Upload ID Document', 'Step 3 of 3'),
          const SizedBox(height: 32),
          if (_hasIdDocument) ...[
            const Center(
              child: Column(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFFF5BB1B), size: 64),
                  SizedBox(height: 16),
                  Text(
                    'ID document already uploaded',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ] else ...[
            Center(
              child: GestureDetector(
                onTap: () => _pickImage(false),
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.primaryColor,
                      width: 2,
                    ),
                    image: _idDocumentImage != null
                        ? DecorationImage(
                            image: FileImage(_idDocumentImage!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _idDocumentImage == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.document_scanner_outlined,
                              size: 60,
                              color: AppTheme.primaryColor,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Tap to upload ID',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Please upload a clear photo of your National ID or Passport. Ensure all details are readable.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 40),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildStepTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.primaryColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? hint,
    bool readOnly = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: AppTheme.textSecondary),
          hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.6)),
          prefixIcon: Icon(icon, color: AppTheme.primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppTheme.backgroundLight,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        if (_currentStep > 0) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: _previousStep,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: const BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
              child: const Text(
                'Back',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
        Expanded(
          child: ElevatedButton(
            onPressed: _canProceed() && !_isLoading ? _nextStep : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              disabledBackgroundColor: AppTheme.primaryColor.withOpacity(0.5),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    _currentStep == 2 ? 'Complete' : 'Continue',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
