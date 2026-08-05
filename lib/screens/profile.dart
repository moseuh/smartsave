import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import '../constants/app_constants.dart';
import '../constants/app_theme.dart';
import 'dart:io' show File;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'modern_login_screen.dart';
import '../services/transaction_auth_service.dart';

class Profile extends StatefulWidget {
  final String userId;
  const Profile({super.key, required this.userId});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  Map<String, dynamic>? userDetails;
  bool isLoading = true;
  bool isUploading = false;
  bool isSavingDetails = false;
  final ImagePicker _picker = ImagePicker();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  DateTime? _selectedDob;

  // Security
  bool _pinSet = false;
  bool _bioAvailable = false;
  bool _bioEnabled = false;

  @override
  void initState() {
    super.initState();
    _validateAndFetchUserDetails();
    _loadSecurityState();
  }

  Future<void> _loadSecurityState() async {
    final pinSet = await TransactionAuthService.hasPin();
    final bioAvail = await TransactionAuthService.isBioAvailable();
    final bioEnabled = await TransactionAuthService.isBioEnabled();
    if (mounted) setState(() { _pinSet = pinSet; _bioAvailable = bioAvail; _bioEnabled = bioEnabled; });
  }

  Future<void> _toggleBio(bool v) async {
    if (v) {
      // Trigger a real biometric prompt — this requests permission on first use
      final ok = await TransactionAuthService.authenticateBio();
      if (!mounted) return;
      if (!ok) {
        // User denied or no biometric enrolled — don't enable
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication failed or not set up on this device.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    await TransactionAuthService.setBioEnabled(v);
    if (mounted) setState(() => _bioEnabled = v);
  }

  Future<void> _changePin() async {
    // Clear existing PIN so the setup flow triggers on next authenticate() call
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('txn_pin_hash');
    if (!mounted) return;
    final ok = await TransactionAuthService.authenticate(context);
    if (ok && mounted) {
      setState(() => _pinSet = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN updated successfully'), backgroundColor: Color(0xFF1B6631)),
      );
    } else {
      // Restore if user cancelled without finishing
      await _loadSecurityState();
    }
  }

  Future<void> _validateAndFetchUserDetails() async {
    if (widget.userId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid user ID. Please log in again.')),
      );
      await _logout();
      return;
    }
    await fetchUserDetails();
  }

  Future<void> fetchUserDetails() async {
    setState(() => isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/user-details/${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            userDetails = data['data'];
            isLoading = false;
          });
        } else {
          throw Exception(data['message'] ?? 'Failed to load user details');
        }
      } else if (response.statusCode == 404) {
        throw Exception('User not found. Please log in again.');
      } else {
        throw Exception('Failed to load user details: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading profile: $e'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: fetchUserDetails,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  String _formatDob(String raw) {
    if (raw.isEmpty) return 'N/A';
    try {
      return DateFormat('d MMMM yyyy').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  void _openEditDetails() {
    final name = userDetails?['full_name'] ?? '';
    final phone = userDetails?['phone_number'] ?? '';
    final dob = userDetails?['date_of_birth'] ?? '';
    _nameController.text = name;
    _phoneController.text = phone;
    _dobController.text = dob.contains('T') ? dob.split('T')[0] : dob;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildEditSheet(ctx),
    );
  }

  Widget _buildEditSheet(BuildContext ctx) {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        final mq = MediaQuery.of(context);
        final bottomPadding = mq.viewInsets.bottom + mq.padding.bottom + 24;
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Edit Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              const SizedBox(height: 20),
              _editField(_nameController, 'Full Name', Icons.person_outline),
              const SizedBox(height: 14),
              _editField(_phoneController, 'Phone Number', Icons.phone_outlined, keyboardType: TextInputType.phone),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDob ?? DateTime(2000),
                    firstDate: DateTime(1940),
                    lastDate: DateTime.now(),
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                        colorScheme: const ColorScheme.light(primary: Color(0xFF1B6631)),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    setSheetState(() {
                      _selectedDob = picked;
                      _dobController.text =
                          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                    });
                  }
                },
                child: AbsorbPointer(
                  child: _editField(_dobController, 'Date of Birth', Icons.cake_outlined, hint: 'Tap to select'),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSavingDetails ? null : () => _saveDetails(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B6631),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: isSavingDetails
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _editField(TextEditingController ctrl, String label, IconData icon,
      {TextInputType keyboardType = TextInputType.text, String? hint}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FDF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8F5E2)),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(color: Color(0xFF111827), fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          prefixIcon: Icon(icon, color: const Color(0xFF1B6631), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Future<void> _saveDetails(BuildContext sheetCtx) async {
    setState(() => isSavingDetails = true);
    try {
      final response = await http.put(
        Uri.parse('${AppConstants.apiBaseUrl}/update-profile/${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'full_name': _nameController.text.trim(),
          'phone_number': _phoneController.text.trim(),
          'date_of_birth': _dobController.text.trim(),
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        await fetchUserDetails();
        if (mounted) {
          Navigator.pop(sheetCtx);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: Color(0xFF1B6631),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Update failed')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => isSavingDetails = false);
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const ModernLoginScreen()),
    );
  }


  Future<void> _changeProfilePicture() async {
    if (isUploading) return;

    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Source'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('Camera'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('Gallery'),
          ),
        ],
      ),
    );

    if (source == null) return;

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      File imageFile = File(pickedFile.path);
      await _uploadProfilePicture(imageFile);
      await fetchUserDetails();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error changing profile picture: $e')),
        );
      }
    }
  }

  Future<void> _uploadProfilePicture(File image) async {
    setState(() => isUploading = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConstants.apiBaseUrl}/upload-profile-picture/${widget.userId}'),
      );

      request.files.add(await http.MultipartFile.fromPath('profile_picture', image.path));

      var response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final responseData = jsonDecode(responseBody);

      setState(() => isUploading = false);

      if (response.statusCode == 200 && responseData['status'] == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture updated successfully')),
          );
        }
      } else {
        throw Exception(responseData['message'] ?? 'Upload failed');
      }
    } catch (e) {
      setState(() => isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = userDetails?['full_name'] ?? 'User';
    final email = userDetails?['email'] ?? '';
    final phone = userDetails?['phone_number'] ?? '';
    final dob = userDetails?['date_of_birth'] ?? '';
    final selfie = userDetails?['selfie_path'];
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : 'U';

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.financeGreenV3))
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 220,
                  pinned: true,
                  backgroundColor: AppTheme.backgroundLight,
                  leading: const SizedBox.shrink(),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      color: AppTheme.backgroundLight,
                      child: SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: isUploading ? null : _changeProfilePicture,
                              child: Stack(
                                children: [
                                  Container(
                                    width: 88,
                                    height: 88,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.financeGreen.withValues(alpha: 0.3), width: 3),
                                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12)],
                                    ),
                                    child: ClipOval(
                                      child: selfie != null && selfie.toString().isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: selfie.toString(),
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) => _buildInitialsAvatar(initials),
                                            )
                                          : _buildInitialsAvatar(initials),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.financeGreen,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                                    ),
                                  ),
                                  if (isUploading)
                                    const Positioned.fill(
                                      child: CircularProgressIndicator(color: AppColors.financeGreen, strokeWidth: 2),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(name, style: const TextStyle(color: Color(0xFF111827), fontSize: 20, fontWeight: FontWeight.bold)),
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(email, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        const Text('Account Information', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildInfoCard([
                          _buildInfoRow(Icons.person_outline, 'Full Name', name),
                          _buildInfoRow(Icons.email_outlined, 'Email', email.isNotEmpty ? email : 'N/A'),
                          _buildInfoRow(Icons.phone_outlined, 'Phone Number', phone.isNotEmpty ? phone : 'N/A'),
                          _buildInfoRow(Icons.cake_outlined, 'Date of Birth', _formatDob(dob)),
                        ]),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _openEditDetails,
                            icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF1B6631)),
                            label: const Text('Edit Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B6631))),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFF1B6631), width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text('Security', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(children: [
                            // Fingerprint toggle — only shown if device supports biometrics
                            if (_bioAvailable) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                child: Row(children: [
                                  Container(
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(
                                      color: AppColors.financeGreen.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.fingerprint, color: AppColors.financeGreen, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text('Fingerprint / Face ID', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                                      Text('Use biometrics to unlock & confirm payments', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                                    ]),
                                  ),
                                  Switch(
                                    value: _bioEnabled,
                                    onChanged: _toggleBio,
                                    activeThumbColor: AppColors.financeGreen,
                                    activeTrackColor: AppColors.financeGreen.withValues(alpha: 0.4),
                                  ),
                                ]),
                              ),
                              const Divider(height: 1, indent: 16, endIndent: 16),
                            ],
                            // Change / set PIN
                            InkWell(
                              onTap: _changePin,
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: Row(children: [
                                  Container(
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.pin_outlined, color: Color(0xFF6366F1), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(_pinSet ? 'Change Transaction PIN' : 'Set Transaction PIN',
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                                      Text(_pinSet ? '4-digit PIN used to confirm payments' : 'Protect transactions with a 4-digit PIN',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                                    ]),
                                  ),
                                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
                                ]),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout, size: 18),
                            label: const Text('Log Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.errorColor,
                              foregroundColor: AppTheme.textLight,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInitialsAvatar(String initials) {
    return Container(
      color: AppColors.financeGreenV2,
      alignment: Alignment.center,
      child: Text(initials, style: const TextStyle(color: AppColors.coreWhite, fontSize: 28, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildInfoCard(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.financeGreen.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(children: rows),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.financeGreen.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.financeGreen, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}