import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/app_constants.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/graph.dart' as graph;
import 'buygoodselect.dart';
import 'loans_page.dart';
import 'modern_login_screen.dart';
import 'profile.dart';

class JobsPage extends StatefulWidget {
  final String userId;
  const JobsPage({super.key, required this.userId});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic>? userDetails;
  List<dynamic>? jobs;
  bool isLoading = true;
  bool isSubscribedToAlerts = false;
  int _selectedIndex = 2;
  String _selectedCategory = 'all';
  final _salaryController = TextEditingController();
  final _cvController = TextEditingController();
  final _portfolioController = TextEditingController();
  final _referencesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Position? _currentPosition;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  // Dummy data for preview
  final Map<String, dynamic> _dummyJobs = {
    "status": "success",
    "message": "Jobs retrieved successfully",
    "data": [
      {
        "id": "1",
        "title": "Bank Teller",
        "category": "office",
        "salary": 50000,
        "location": "Westlands, Nairobi",
        "latitude": -1.2675,
        "longitude": 36.8113,
        "urgency": "standard",
        "duration": null,
        "description": "Handle customer transactions, manage cash drawers, and provide excellent customer service at a leading bank.",
        "date_posted": "2025-08-27",
        "time_posted": "09:00 AM"
      },
      {
        "id": "2",
        "title": "Construction Worker",
        "category": "blue_collar",
        "salary": 15000,
        "location": "Westlands, Nairobi",
        "latitude": -1.2678,
        "longitude": 36.8115,
        "urgency": "standard",
        "duration": "1 day",
        "description": "Assist in building and maintaining structures, including masonry and carpentry tasks.",
        "date_posted": "2025-08-27",
        "time_posted": "10:30 AM"
      },
      {
        "id": "3",
        "title": "Urgent Boda Rider",
        "category": "urgent",
        "salary": 5000,
        "location": "Westlands, Nairobi",
        "latitude": -1.2676,
        "longitude": 36.8114,
        "urgency": "urgent",
        "duration": "4 hours",
        "description": "Deliver packages and goods across Westlands on a motorbike. Requires valid license and fast response.",
        "date_posted": "2025-08-28",
        "time_posted": "07:00 AM"
      },
      {
        "id": "4",
        "title": "Freelance Writer",
        "category": "remote",
        "salary": 30000,
        "location": "Remote",
        "latitude": null,
        "longitude": null,
        "urgency": "standard",
        "duration": "1 month",
        "description": "Write engaging articles and blog posts for online platforms. Flexible hours, work from home.",
        "date_posted": "2025-08-26",
        "time_posted": "02:00 PM"
      },
      {
        "id": "5",
        "title": "Furniture Mover",
        "category": "casual",
        "salary": 2000,
        "location": "Westlands, Nairobi",
        "latitude": -1.2677,
        "longitude": 36.8116,
        "urgency": "standard",
        "duration": "2 hours",
        "description": "Assist in moving furniture for a residential relocation. Physical strength required.",
        "date_posted": "2025-08-28",
        "time_posted": "08:00 AM"
      },
      {
        "id": "6",
        "title": "Short-Term Consultant",
        "category": "professional",
        "salary": 80000,
        "location": "Westlands, Nairobi",
        "latitude": -1.2674,
        "longitude": 36.8112,
        "urgency": "standard",
        "duration": "3 months",
        "description": "Provide strategic advice to a startup on business development and market expansion.",
        "date_posted": "2025-08-25",
        "time_posted": "11:00 AM"
      },
      {
        "id": "7",
        "title": "Executive Manager",
        "category": "top_cream",
        "salary": 150000,
        "location": "Westlands, Nairobi",
        "latitude": -1.2673,
        "longitude": 36.8111,
        "urgency": "standard",
        "duration": null,
        "description": "Lead a team of professionals in a corporate setting, overseeing operations and strategy.",
        "date_posted": "2025-08-24",
        "time_posted": "09:30 AM"
      },
      {
        "id": "8",
        "title": "TikTok Product Promo",
        "category": "influencer",
        "salary": 2000,
        "location": "Westlands, Nairobi",
        "latitude": -1.2679,
        "longitude": 36.8117,
        "urgency": "urgent",
        "duration": "2 hours",
        "description": "Create and post a promotional video for a new product on TikTok. Must have a following of 10K+.",
        "date_posted": "2025-08-28",
        "time_posted": "10:00 AM"
      }
    ]
  };

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadSubscriptionStatus();
    _validateAndFetchData();
  }

  @override
  void dispose() {
    _salaryController.dispose();
    _cvController.dispose();
    _portfolioController.dispose();
    _referencesController.dispose();
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'job_channel',
      'Job Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      0,
      title,
      body,
      notificationDetails,
    );
  }

  Future<void> _loadSubscriptionStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      isSubscribedToAlerts = prefs.getBool('job_alerts_subscribed') ?? false;
    });
  }

  Future<void> _saveSubscriptionStatus(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('job_alerts_subscribed', value);
    setState(() {
      isSubscribedToAlerts = value;
    });
  }

  Future<void> _validateAndFetchData() async {
    if (widget.userId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid user ID. Please log in again.')),
        );
        await _logout();
      }
      return;
    }
    await fetchUserDetails();
    if (userDetails != null && userDetails!['face_verified'] == true) {
      await _getCurrentLocation();
      if (_currentPosition != null) {
        await fetchJobs();
        if (isSubscribedToAlerts) {
          _checkForNearbyJobs();
        }
      } else {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied. Using default job list.')),
          );
          await fetchJobs();
        }
      }
    } else {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Face verification required. Please update your profile.')),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    _currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> fetchUserDetails() async {
    setState(() {
      isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/user-details/${widget.userId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            userDetails = data['data'];
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
      if (mounted) {
        setState(() {
          isLoading = false;
        });
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
  }

  Future<void> fetchJobs() async {
    try {
      setState(() {
        jobs = _dummyJobs['data'];
        isLoading = false;
      });
      if (isSubscribedToAlerts) {
        await _showNotification('New jobs available', 'Check out new opportunities in Westlands!');
      }
      return;
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading jobs: $e'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: fetchJobs,
            ),
          ),
        );
      }
    }
  }

  Future<void> _checkForNearbyJobs() async {
    if (_currentPosition == null || jobs == null) return;
    for (var job in jobs!) {
      if (job['latitude'] != null && job['longitude'] != null) {
        final distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          job['latitude'].toDouble(),
          job['longitude'].toDouble(),
        );
        if (distance <= 300) {
          await _showNotification(
            'New jobs near you â€“ 300m away',
            'Check out ${job['title']} in ${job['location']}!',
          );
        }
        if (job['urgency'] == 'urgent') {
          await _showNotification(
            'Urgent ${job['title']} needed in your area',
            'Apply now for ${job['title']} in ${job['location']}!',
          );
        }
      }
    }
  }

  Future<void> applyForJob(String jobId) async {
    setState(() {
      isLoading = true;
    });

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Job application submitted for job ID: $jobId')),
        );
        setState(() {
          isLoading = false;
        });
      }
      return;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error applying for job: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> shareJob(String jobTitle, String jobDescription, String jobLocation) async {
    try {
      await Share.share(
        'Check out this job: $jobTitle\nDescription: $jobDescription\nLocation: $jobLocation\nApply now!',
        subject: 'Job Opportunity: $jobTitle',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing job: $e')),
        );
      }
    }
  }

  Future<void> submitPremiumProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile submitted for premium referral')),
        );
        setState(() {
          isLoading = false;
        });
      }
      return;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ModernLoginScreen()),
      );
    }
  }

  void _onItemTapped(int index) {
    if (!mounted) return;
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => graph.SavingsDashboard(userId: widget.userId)),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoansPage(userId: widget.userId)),
      );
    } else if (index == 2) {
      // Stay on Jobs page
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => BuyGoodsSelect(userId: widget.userId)),
      );
    } else if (index == 4) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => Profile(userId: widget.userId)),
      );
    }
  }

  void _showPremiumProfileDialog() {
    if (userDetails?['premium_status'] != true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Premium subscription required for direct referrals.')),
        );
      }
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardLight,
        title: const Text(
          'Submit Premium Profile',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _cvController,
                  decoration: const InputDecoration(
                    labelText: 'CV URL',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.textSecondary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.financeGreenV3),
                    ),
                  ),
                  style: const TextStyle(color: AppTheme.cardLight),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter CV URL';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _portfolioController,
                  decoration: const InputDecoration(
                    labelText: 'Portfolio URL',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.textSecondary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.financeGreenV3),
                    ),
                  ),
                  style: const TextStyle(color: AppTheme.cardLight),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter portfolio URL';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _referencesController,
                  decoration: const InputDecoration(
                    labelText: 'References',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.textSecondary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.financeGreenV3),
                    ),
                  ),
                  style: const TextStyle(color: AppTheme.cardLight),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter references';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: submitPremiumProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.financeGreenV3,
              foregroundColor: Colors.black,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardLight,
        title: const Text(
          'Filter Jobs',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.textSecondary),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.financeGreenV3),
                  ),
                ),
                dropdownColor: AppColors.coreWhiteW1,
                style: const TextStyle(color: AppTheme.cardLight),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Jobs')),
                  DropdownMenuItem(value: 'office', child: Text('Office Jobs')),
                  DropdownMenuItem(value: 'blue_collar', child: Text('Blue-Collar Gigs')),
                  DropdownMenuItem(value: 'urgent', child: Text('Urgent On-Demand')),
                  DropdownMenuItem(value: 'remote', child: Text('Remote Jobs')),
                  DropdownMenuItem(value: 'casual', child: Text('Casual/On-Demand')),
                  DropdownMenuItem(value: 'professional', child: Text('Professional/Transitional')),
                  DropdownMenuItem(value: 'top_cream', child: Text('Top Cream Jobs')),
                  DropdownMenuItem(value: 'influencer', child: Text('Influencer & Micro-Gigs')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCategory = value;
                      jobs = _dummyJobs['data'].where((job) {
                        return _selectedCategory == 'all' || job['category'] == _selectedCategory;
                      }).toList();
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _salaryController,
                decoration: const InputDecoration(
                  labelText: 'Minimum Salary (KSh)',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.textSecondary),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.financeGreenV3),
                  ),
                ),
                style: const TextStyle(color: AppTheme.cardLight),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final salary = double.tryParse(value);
                    if (salary == null || salary < 0) {
                      return 'Please enter a valid salary';
                    }
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {
                    jobs = _dummyJobs['data'].where((job) {
                      final minSalary = double.tryParse(value) ?? 0;
                      return (_selectedCategory == 'all' || job['category'] == _selectedCategory) &&
                          (job['salary'] >= minSalary);
                    }).toList();
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              fetchJobs();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.financeGreenV3,
              foregroundColor: Colors.black,
            ),
            child: const Text('Apply Filters'),
          ),
        ],
      ),
    );
  }

  void _showJobAlertsDialog() {
    bool tempSubscribed = isSubscribedToAlerts;
    String selectedFrequency = 'daily';
    List<String> selectedCategories = ['all'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardLight,
        title: const Text(
          'Subscribe to Job Alerts',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Receive notifications for new job postings.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Enable Job Alerts', style: TextStyle(color: AppTheme.cardLight)),
                  value: tempSubscribed,
                  activeColor: AppColors.financeGreenV3,
                  onChanged: (value) {
                    setState(() {
                      tempSubscribed = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Notification Frequency',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
                DropdownButtonFormField<String>(
                  value: selectedFrequency,
                  decoration: const InputDecoration(
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.textSecondary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.financeGreenV3),
                    ),
                  ),
                  dropdownColor: AppColors.coreWhiteW1,
                  style: const TextStyle(color: AppTheme.cardLight),
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'instant', child: Text('Instant')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedFrequency = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Preferred Categories',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    'all',
                    'office',
                    'blue_collar',
                    'urgent',
                    'remote',
                    'casual',
                    'professional',
                    'top_cream',
                    'influencer'
                  ].map((category) {
                    return ChoiceChip(
                      label: Text(category == 'all' ? 'All Jobs' : category.replaceAll('_', ' ').capitalize()),
                      selected: selectedCategories.contains(category),
                      selectedColor: AppColors.financeGreenV3,
                      labelStyle: TextStyle(
                        color: selectedCategories.contains(category) ? Colors.black : AppTheme.textSecondary,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          if (category == 'all') {
                            selectedCategories = ['all'];
                          } else {
                            if (selectedCategories.contains('all')) {
                              selectedCategories.remove('all');
                            }
                            if (selected) {
                              selectedCategories.add(category);
                            } else {
                              selectedCategories.remove(category);
                            }
                            if (selectedCategories.isEmpty) {
                              selectedCategories.add('all');
                            }
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              _saveSubscriptionStatus(tempSubscribed);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(tempSubscribed
                        ? 'Subscribed to job alerts ($selectedFrequency, ${selectedCategories.join(', ')})'
                        : 'Unsubscribed from job alerts'),
                  ),
                );
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.financeGreenV3,
              foregroundColor: Colors.black,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.coreDark,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70.0),
        child: Container(
          decoration: const BoxDecoration(
            color: AppTheme.cardLight,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.menu, color: AppTheme.cardLight),
                  onPressed: () {
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        userDetails != null ? userDetails!['full_name'] ?? 'User' : 'Loading...',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Member since 2022',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.notifications, color: AppTheme.cardLight),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
      drawer: Drawer(
        backgroundColor: AppTheme.cardLight,
        width: 250,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF1F2937),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.coreWhiteW2,
                    child: userDetails != null && userDetails!['selfie_path'] != null
                        ? CachedNetworkImage(
                            imageUrl: userDetails!['selfie_path'],
                            fit: BoxFit.cover,
                            width: 56,
                            height: 56,
                          )
                        : const Icon(Icons.person, size: 28, color: AppTheme.cardLight),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    userDetails != null ? userDetails!['full_name'] ?? 'User' : 'Loading...',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                  ),
                  Text(
                    userDetails != null ? userDetails!['email'] ?? '' : '',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet, color: AppColors.financeGreenV3),
              title: const Text('Wallet', style: TextStyle(color: AppTheme.cardLight)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to Wallet page
              },
            ),
            ListTile(
              leading: const Icon(Icons.work, color: AppColors.financeGreenV3),
              title: const Text('Jobs', style: TextStyle(color: AppTheme.cardLight)),
              onTap: () {
                Navigator.pop(context);
                // Already on Jobs page
              },
            ),
            ListTile(
              leading: const Icon(Icons.school, color: AppColors.financeGreenV3),
              title: const Text('Scholarships & Funding', style: TextStyle(color: AppTheme.cardLight)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to Scholarships page
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: AppColors.financeGreenV3),
              title: const Text('Chat', style: TextStyle(color: AppTheme.cardLight)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to Chat page
              },
            ),
            ListTile(
              leading: const Icon(Icons.leaderboard, color: AppColors.financeGreenV3),
              title: const Text('Leaderboard', style: TextStyle(color: AppTheme.cardLight)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to Leaderboard page
              },
            ),
            ListTile(
              leading: const Icon(Icons.class_, color: AppColors.financeGreenV3),
              title: const Text('Classes', style: TextStyle(color: AppTheme.cardLight)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to Classes page
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance, color: AppColors.financeGreenV3),
              title: const Text('Loans & Credit', style: TextStyle(color: AppTheme.cardLight)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoansPage(userId: widget.userId)),
                );
              },
            ),
          ],
        ),
      ),
      drawerEnableOpenDragGesture: true,
      body: isLoading
          ? const Center(
              child: SpinKitFadingCircle(
                color: AppColors.financeGreenV3,
                size: 50.0,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Jobs & Opportunities',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: userDetails?['premium_status'] == true ? _showPremiumProfileDialog : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: userDetails?['premium_status'] == true
                                  ? AppColors.financeGreenV3
                                  : Colors.grey,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Premium Referral'),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.filter_list, color: AppColors.financeGreenV3),
                            onPressed: _showFilterDialog,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: AppTheme.cardLight,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Location: ${_currentPosition != null ? 'Westlands, Nairobi' : 'All Locations'}',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Total Jobs: ${jobs?.length ?? 0}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ExpansionTile(
                    title: const Text(
                      'Job Alerts Subscription',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      isSubscribedToAlerts ? 'Subscribed' : 'Not Subscribed',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                    leading: Icon(
                      isSubscribedToAlerts ? Icons.notifications_active : Icons.notifications_off,
                      color: AppColors.financeGreenV3,
                    ),
                    backgroundColor: AppColors.coreWhiteW1,
                    collapsedBackgroundColor: AppColors.coreWhiteW1,
                    children: [
                      ListTile(
                        title: const Text(
                          'Manage Job Alerts',
                          style: TextStyle(color: AppTheme.cardLight),
                        ),
                        subtitle: const Text(
                          'Configure notifications for new job postings.',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        onTap: _showJobAlertsDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  jobs == null || jobs!.isEmpty
                      ? const Center(
                          child: Text(
                            'No jobs found',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: jobs!.length,
                          itemBuilder: (context, index) {
                            final job = jobs![index];
                            return Card(
                              color: AppColors.coreWhiteW1,
                              margin: const EdgeInsets.symmetric(vertical: 8.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ExpansionTile(
                                title: Text(
                                  '${job['title']} - KSh ${job['salary']?.toStringAsFixed(2) ?? 'N/A'}',
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'Location: ${job['location'] ?? 'N/A'}',
                                  style: const TextStyle(color: AppTheme.textSecondary),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Description: ${job['description'] ?? 'N/A'}',
                                          style: const TextStyle(color: AppTheme.textSecondary),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Posted: ${job['date_posted'] ?? 'N/A'} at ${job['time_posted'] ?? 'N/A'}',
                                          style: const TextStyle(color: AppTheme.textSecondary),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Category: ${job['category'] ?? 'N/A'}',
                                          style: const TextStyle(color: AppTheme.textSecondary),
                                        ),
                                        Text(
                                          'Urgency: ${job['urgency'] ?? 'Standard'}',
                                          style: const TextStyle(color: AppTheme.textSecondary),
                                        ),
                                        if (job['duration'] != null)
                                          Text(
                                            'Gig Duration: ${job['duration']}',
                                            style: const TextStyle(color: AppTheme.textSecondary),
                                          ),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            if (job['category'] == 'top_cream' && userDetails?['premium_status'] != true)
                                              const Icon(Icons.lock, color: Colors.grey),
                                            if (job['category'] != 'top_cream' || userDetails?['premium_status'] == true) ...[
                                              ElevatedButton(
                                                onPressed: () => applyForJob(job['id'].toString()),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.financeGreenV3,
                                                  foregroundColor: Colors.black,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                                child: const Text('Apply'),
                                              ),
                                              const SizedBox(width: 8),
                                              ElevatedButton(
                                                onPressed: () => shareJob(
                                                  job['title'],
                                                  job['description'] ?? 'N/A',
                                                  job['location'] ?? 'N/A',
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppTheme.textSecondary,
                                                  foregroundColor: Colors.black,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                                child: const Text('Share'),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppTheme.cardLight,
            selectedItemColor: AppColors.financeGreenV3,
            unselectedItemColor: AppTheme.textSecondary,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_balance),
                label: 'Loans',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.work),
                label: 'Jobs',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.payment),
                label: 'Payments',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
    );
  }
}

// Extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}


