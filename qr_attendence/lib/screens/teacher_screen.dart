import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_attendence/screens/teacher_lectures_history.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';

class TeacherScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String userEmail;
  final Map<String, dynamic>? userData;

  const TeacherScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.userData,
  });

  @override
  State<TeacherScreen> createState() => _TeacherScreenState();
}

class _TeacherScreenState extends State<TeacherScreen>
    with SingleTickerProviderStateMixin {
  String qrData = "";
  Timer? timer;
  bool isLoading = true;
  String teacherName = "";
  String teacherDepartment = "";
  int remainingSeconds = 30;
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  // Location variables
  Position? _currentPosition;
  String _currentAddress = "";
  bool _isLocationEnabled = false;
  bool _isLoadingLocation = false;

  // University-specific variables
  String selectedCourse = "";
  String selectedBatch = "";
  String selectedSemester = "";
  String selectedSubject = "";
  String selectedTimeSlot = "";
  DateTime selectedDate = DateTime.now();

  // Persistent lecture ID for the entire session
  String currentLectureId = "";

  List<String> courses = [];
  List<String> batches = [];
  List<String> semesters = [];
  List<String> subjects = [];
  List<String> timeSlots = [];

  bool isQrGenerated = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    );
    _progressAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(_animationController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTeacherData();
      _checkLocationPermission();
    });
  }

  Future<void> _checkLocationPermission() async {
    final status = await Permission.location.status;

    if (status.isDenied) {
      final result = await Permission.location.request();
      if (result.isGranted) {
        setState(() {
          _isLocationEnabled = true;
        });
        await _getCurrentLocation();
      }
    } else if (status.isGranted) {
      setState(() {
        _isLocationEnabled = true;
      });
      await _getCurrentLocation();
    } else if (status.isPermanentlyDenied) {
      _showLocationSettingsDialog();
    }
  }

  void _showLocationSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'Location permission is required to mark attendance with geotagging. '
          'Please enable location permission in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    if (!_isLocationEnabled) return;

    setState(() {
      _isLoadingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable location services'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationSettingsDialog();
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
      });

      // Get address from coordinates
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        setState(() {
          _currentAddress = [
            placemark.name,
            placemark.locality,
            placemark.administrativeArea,
            placemark.country,
          ].where((e) => e != null && e.isNotEmpty).join(', ');
        });
      }
    } catch (e) {
      print('Error getting location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _loadTeacherData() async {
    if (widget.userData != null && widget.userData!.isNotEmpty) {
      setState(() {
        teacherName = widget.userData?['name'] ?? widget.userName;
        teacherDepartment = widget.userData?['department'] ?? '';
      });
      await _loadCoursesAndData();
      setState(() {
        isLoading = false;
      });
    } else {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get();

        if (doc.exists) {
          setState(() {
            teacherName = doc['name'] ?? widget.userName;
            teacherDepartment = doc['department'] ?? '';
          });
        } else {
          setState(() {
            teacherName = widget.userName;
          });
        }

        await _loadCoursesAndData();
        setState(() {
          isLoading = false;
        });
      } catch (e) {
        print('Error loading teacher data: $e');
        setState(() {
          teacherName = widget.userName;
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadCoursesAndData() async {
    try {
      // Define courses based on department
      if (teacherDepartment == 'Computer Science' ||
          teacherDepartment == 'CS') {
        courses = [
          'BSCS (Bachelor of Computer Science) - 4 Years',
          'MSCS (Master of Computer Science) - 2 Years',
          'PhD Computer Science - 5 Years',
        ];
      } else if (teacherDepartment == 'Software Engineering' ||
          teacherDepartment == 'SE') {
        courses = [
          'BSSE (Bachelor of Software Engineering) - 4 Years',
          'MSSE (Master of Software Engineering) - 2 Years',
          'PhD Software Engineering - 5 Years',
        ];
      } else if (teacherDepartment == 'Information Technology' ||
          teacherDepartment == 'IT') {
        courses = [
          'BSIT (Bachelor of Information Technology) - 4 Years',
          'MSIT (Master of Information Technology) - 2 Years',
          'PhD IT - 5 Years',
        ];
      } else {
        courses = [
          'Bachelor Program - 4 Years',
          'Master Program - 2 Years',
          'Doctoral Program - 5 Years',
        ];
      }

      courses = courses.toSet().toList();

      if (courses.isNotEmpty) selectedCourse = courses.first;

      _generateBatches();
      _generateSemesters();
      await _loadAllSubjects();
      _generateTimeSlots();

      if (batches.isNotEmpty) selectedBatch = batches.first;
      if (semesters.isNotEmpty) selectedSemester = semesters.first;
      if (subjects.isNotEmpty) selectedSubject = subjects.first;
      if (timeSlots.isNotEmpty) selectedTimeSlot = timeSlots.first;
    } catch (e) {
      print('Error loading courses: $e');
    }
  }

  void _generateBatches() {
    int currentYear = DateTime.now().year;
    Set<String> uniqueBatches = {};

    if (selectedCourse.contains('Bachelor') ||
        selectedCourse.contains('BSCS') ||
        selectedCourse.contains('BSSE') ||
        selectedCourse.contains('BSIT')) {
      for (int i = 0; i < 4; i++) {
        int batchYear = currentYear - i;
        uniqueBatches.add('Batch $batchYear - ${batchYear + 4}');
      }
    } else if (selectedCourse.contains('Master') ||
        selectedCourse.contains('MSCS') ||
        selectedCourse.contains('MSSE') ||
        selectedCourse.contains('MSIT')) {
      for (int i = 0; i < 2; i++) {
        int batchYear = currentYear - i;
        uniqueBatches.add('Batch $batchYear - ${batchYear + 2}');
      }
    } else if (selectedCourse.contains('PhD') ||
        selectedCourse.contains('Doctoral')) {
      for (int i = 0; i < 5; i++) {
        int batchYear = currentYear - i;
        uniqueBatches.add('Batch $batchYear - ${batchYear + 5}');
      }
    } else {
      for (int i = 0; i < 4; i++) {
        int batchYear = currentYear - i;
        uniqueBatches.add('Batch $batchYear - ${batchYear + 4}');
      }
    }

    batches = uniqueBatches.toList();
    batches.sort();
  }

  void _generateSemesters() {
    Set<String> uniqueSemesters = {};

    if (selectedCourse.contains('Bachelor') ||
        selectedCourse.contains('BSCS') ||
        selectedCourse.contains('BSSE') ||
        selectedCourse.contains('BSIT')) {
      for (int i = 1; i <= 8; i++) {
        uniqueSemesters.add('Semester $i');
      }
    } else if (selectedCourse.contains('Master') ||
        selectedCourse.contains('MSCS') ||
        selectedCourse.contains('MSSE') ||
        selectedCourse.contains('MSIT')) {
      for (int i = 1; i <= 4; i++) {
        uniqueSemesters.add('Semester $i');
      }
    } else if (selectedCourse.contains('PhD') ||
        selectedCourse.contains('Doctoral')) {
      for (int i = 1; i <= 10; i++) {
        uniqueSemesters.add('Semester $i');
      }
    } else {
      for (int i = 1; i <= 8; i++) {
        uniqueSemesters.add('Semester $i');
      }
    }

    semesters = uniqueSemesters.toList();
    semesters.sort((a, b) {
      int numA = int.parse(a.split(' ')[1]);
      int numB = int.parse(b.split(' ')[1]);
      return numA.compareTo(numB);
    });
  }

  Future<void> _loadAllSubjects() async {
    Set<String> uniqueSubjects = {};

    // Computer Science Department Subjects
    if (teacherDepartment == 'Computer Science' || teacherDepartment == 'CS') {
      if (selectedCourse.contains('Bachelor') ||
          selectedCourse.contains('BSCS')) {
        uniqueSubjects.addAll([
          'Programming Fundamentals',
          'Introduction to Computing',
          'Calculus',
          'English Composition',
          'Islamic Studies',
          'Object Oriented Programming',
          'Digital Logic Design',
          'Discrete Structures',
          'Technical Writing',
          'Pakistan Studies',
          'Data Structures & Algorithms',
          'Database Systems',
          'Computer Organization',
          'Probability & Statistics',
          'Linear Algebra',
          'Operating Systems',
          'Software Engineering',
          'Theory of Automata',
          'Numerical Computing',
          'Multivariable Calculus',
          'Computer Networks',
          'Web Development',
          'Artificial Intelligence',
          'Design & Analysis of Algorithms',
          'Professional Practices',
          'Mobile App Development',
          'Cloud Computing',
          'Information Security',
          'Human Computer Interaction',
          'Data Mining',
          'Machine Learning',
          'Network Security',
          'Parallel & Distributed Computing',
          'Digital Image Processing',
          'Final Year Project Part 1',
          'Big Data Analytics',
          'Internet of Things',
          'Blockchain Technologies',
          'Computer Vision',
          'Final Year Project Part 2',
        ]);
      } else if (selectedCourse.contains('Master') ||
          selectedCourse.contains('MSCS')) {
        uniqueSubjects.addAll([
          'Advanced Algorithms',
          'Advanced Database Systems',
          'Research Methodology',
          'Advanced Operating Systems',
          'Advanced Computer Networks',
          'Advanced Software Engineering',
          'Machine Learning',
          'Data Science',
          'Big Data Analytics',
          'Cloud Computing',
          'Network Security',
          'Digital Image Processing',
          'Artificial Intelligence',
          'Internet of Things',
          'Thesis Part 1',
          'Thesis Part 2',
        ]);
      } else {
        uniqueSubjects.addAll([
          'Advanced Research Methods',
          'PhD Seminar',
          'Dissertation Research',
          'Advanced Topics in CS',
          'Research Publication',
          'Proposal Writing',
          'Thesis Defense',
          'Advanced Machine Learning',
        ]);
      }
    }
    // Software Engineering Department Subjects
    else if (teacherDepartment == 'Software Engineering' ||
        teacherDepartment == 'SE') {
      if (selectedCourse.contains('Bachelor') ||
          selectedCourse.contains('BSSE')) {
        uniqueSubjects.addAll([
          'Programming Fundamentals',
          'Object Oriented Programming',
          'Data Structures',
          'Database Systems',
          'Software Requirements Engineering',
          'Software Design & Architecture',
          'Software Testing & Quality Assurance',
          'Software Project Management',
          'Web Engineering',
          'Mobile Application Development',
          'Cloud Computing',
          'DevOps',
          'Agile Development',
          'User Experience Design',
          'Software Construction',
          'Formal Methods',
          'Software Metrics',
          'Software Maintenance',
          'Final Year Project',
        ]);
      } else if (selectedCourse.contains('Master') ||
          selectedCourse.contains('MSSE')) {
        uniqueSubjects.addAll([
          'Advanced Software Engineering',
          'Software Architecture',
          'Software Quality Management',
          'Agile Methodologies',
          'Software Security',
          'Cloud Native Development',
          'DevOps Practices',
          'Software Process Improvement',
          'Requirements Engineering',
          'Software Testing Advanced',
          'Thesis',
        ]);
      } else {
        uniqueSubjects.addAll([
          'Advanced SE Research',
          'PhD Seminar',
          'Dissertation Research',
          'Advanced Topics in SE',
        ]);
      }
    }
    // Information Technology Department Subjects
    else if (teacherDepartment == 'Information Technology' ||
        teacherDepartment == 'IT') {
      if (selectedCourse.contains('Bachelor') ||
          selectedCourse.contains('BSIT')) {
        uniqueSubjects.addAll([
          'IT Fundamentals',
          'Programming Basics',
          'Web Technologies',
          'Database Management',
          'Network Administration',
          'System Administration',
          'IT Project Management',
          'Cyber Security',
          'Cloud Infrastructure',
          'IT Support',
          'E-commerce Technologies',
          'Digital Marketing',
          'IT Service Management',
          'Enterprise Systems',
          'Business Intelligence',
          'Data Analytics',
          'IT Governance',
          'Final Year Project',
        ]);
      } else if (selectedCourse.contains('Master') ||
          selectedCourse.contains('MSIT')) {
        uniqueSubjects.addAll([
          'Advanced IT Management',
          'IT Strategy',
          'Enterprise Architecture',
          'IT Security Management',
          'Cloud Solutions',
          'Data Center Management',
          'IT Service Delivery',
          'Business Process Management',
          'Digital Transformation',
          'Thesis',
        ]);
      } else {
        uniqueSubjects.addAll([
          'Advanced IT Research',
          'PhD Seminar',
          'Dissertation Research',
          'Advanced Topics in IT',
        ]);
      }
    }
    // General Subjects for other departments
    else {
      uniqueSubjects.addAll([
        'Subject 1',
        'Subject 2',
        'Subject 3',
        'Subject 4',
        'Subject 5',
        'Subject 6',
        'Subject 7',
        'Subject 8',
        'Subject 9',
        'Subject 10',
      ]);
    }

    subjects = uniqueSubjects.toList();
    subjects.sort();
  }

  void _generateTimeSlots() {
    Set<String> uniqueTimeSlots = {
      '08:00 AM - 09:00 AM',
      '09:00 AM - 10:00 AM',
      '10:00 AM - 11:00 AM',
      '11:00 AM - 12:00 PM',
      '12:00 PM - 01:00 PM',
      '01:00 PM - 02:00 PM',
      '02:00 PM - 03:00 PM',
      '03:00 PM - 04:00 PM',
      '04:00 PM - 05:00 PM',
    };

    timeSlots = uniqueTimeSlots.toList();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2026),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1A237E),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        isQrGenerated = false;
        qrData = "";
        _resetLectureSession();
      });
    }
  }

  void _resetLectureSession() {
    setState(() {
      currentLectureId = "";
      isQrGenerated = false;
      qrData = "";
    });
  }

  void generateQR() async {
    if (selectedCourse.isEmpty ||
        selectedBatch.isEmpty ||
        selectedSemester.isEmpty ||
        selectedSubject.isEmpty ||
        selectedTimeSlot.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all lecture details first!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if location is available
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Getting location... Please wait and try again.'),
          backgroundColor: Colors.orange,
        ),
      );
      await _getCurrentLocation();
      if (_currentPosition == null) {
        return;
      }
    }

    try {
      if (currentLectureId.isEmpty) {
        currentLectureId = 'LEC_${DateTime.now().millisecondsSinceEpoch}';
      }

      final now = DateTime.now();

      final lectureInfo = {
        'course': selectedCourse,
        'batch': selectedBatch,
        'semester': selectedSemester,
        'subject': selectedSubject,
        'date': selectedDate.toIso8601String(),
        'timeSlot': selectedTimeSlot,
        'teacherId': widget.userId,
        'teacherName': teacherName,
        'department': teacherDepartment,
        'lectureId': currentLectureId,
        'timestamp': now.toIso8601String(),
        'expiry': now.add(const Duration(seconds: 30)).toIso8601String(),
        // Geotagging information
        'location': {
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
          'address': _currentAddress,
          'accuracy': _currentPosition!.accuracy,
        },
      };

      final generatedData = jsonEncode(lectureInfo);

      if (generatedData.isEmpty) {
        throw Exception("Generated QR data is empty");
      }

      setState(() {
        qrData = generatedData;
        remainingSeconds = 30;
        isQrGenerated = true;
      });

      _resetTimer();

      if (mounted && !isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'QR Code Generated for "$selectedSubject" with location',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error generating QR: $e');
      if (mounted && !isLoading) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating QR: $e')));
      }
    }
  }

  void _resetTimer() {
    timer?.cancel();
    _animationController.reset();
    _animationController.forward();

    timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && isQrGenerated) {
        generateQR();
        _animationController.reset();
        _animationController.forward();
      }
    });
  }

  void _navigateToLectureHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherLectureHistoryScreen(
          teacherId: widget.userId,
          teacherName: teacherName,
        ),
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Location status indicator
          if (_currentPosition != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: Colors.green.shade300,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Location OK',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade300,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.history_edu),
            onPressed: _navigateToLectureHistory,
            tooltip: 'Lecture History',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.blue.shade50, Colors.white],
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTeacherInfoCard(),
                    const SizedBox(height: 20),

                    // Location Status Card
                    _buildLocationStatusCard(),

                    const SizedBox(height: 20),

                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: InkWell(
                        onTap: _navigateToLectureHistory,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF1A237E,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Icon(
                                  Icons.history_edu,
                                  color: Color(0xFF1A237E),
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Lecture History',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A237E),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'View all lectures you have taken',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.grey.shade400,
                                size: 30,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.class_, color: Color(0xFF1A237E)),
                                SizedBox(width: 10),
                                Text(
                                  'Lecture Details',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A237E),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            _buildDropdown(
                              'Course',
                              selectedCourse,
                              courses,
                              Icons.school,
                              (value) {
                                if (value != null && value != selectedCourse) {
                                  setState(() {
                                    selectedCourse = value;
                                    isQrGenerated = false;
                                    qrData = "";
                                    _resetLectureSession();
                                    _generateBatches();
                                    _generateSemesters();
                                    _loadAllSubjects();

                                    if (batches.isNotEmpty)
                                      selectedBatch = batches.first;
                                    if (semesters.isNotEmpty)
                                      selectedSemester = semesters.first;
                                    if (subjects.isNotEmpty)
                                      selectedSubject = subjects.first;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),

                            _buildDropdown(
                              'Batch',
                              selectedBatch,
                              batches,
                              Icons.group,
                              (value) {
                                if (value != null && value != selectedBatch) {
                                  setState(() {
                                    selectedBatch = value;
                                    isQrGenerated = false;
                                    qrData = "";
                                    _resetLectureSession();
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),

                            _buildDropdown(
                              'Semester',
                              selectedSemester,
                              semesters,
                              Icons.grade,
                              (value) {
                                if (value != null &&
                                    value != selectedSemester) {
                                  setState(() {
                                    selectedSemester = value;
                                    isQrGenerated = false;
                                    qrData = "";
                                    _resetLectureSession();
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),

                            _buildDropdown(
                              'Subject',
                              selectedSubject,
                              subjects,
                              Icons.menu_book,
                              (value) {
                                if (value != null && value != selectedSubject) {
                                  setState(() {
                                    selectedSubject = value;
                                    isQrGenerated = false;
                                    qrData = "";
                                    _resetLectureSession();
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),

                            InkWell(
                              onTap: _selectDate,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      color: Color(0xFF1A237E),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Date: ${_formatDate(selectedDate)}',
                                        style: const TextStyle(fontSize: 16),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Icon(Icons.arrow_drop_down),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildDropdown(
                              'Time Slot',
                              selectedTimeSlot,
                              timeSlots,
                              Icons.access_time,
                              (value) {
                                if (value != null &&
                                    value != selectedTimeSlot) {
                                  setState(() {
                                    selectedTimeSlot = value;
                                    isQrGenerated = false;
                                    qrData = "";
                                    _resetLectureSession();
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      onPressed: generateQR,
                      icon: const Icon(Icons.qr_code),
                      label: const Text(
                        'Generate Attendance QR Code',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),

                    if (isQrGenerated && qrData.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildQRDisplayCard(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLocationStatusCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isLocationEnabled && _currentPosition != null
                      ? Icons.location_on
                      : Icons.location_off,
                  color: _isLocationEnabled && _currentPosition != null
                      ? Colors.green
                      : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Location Status',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const Spacer(),
                if (_isLoadingLocation)
                  const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (_currentPosition != null)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: _getCurrentLocation,
                    tooltip: 'Refresh Location',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_currentPosition != null) ...[
              Text(
                '📍 ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              if (_currentAddress.isNotEmpty)
                Text(
                  '🏢 $_currentAddress',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
            ] else if (_isLoadingLocation)
              const Text(
                'Fetching location...',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              )
            else
              Text(
                'Location not available. Tap refresh to enable.',
                style: TextStyle(fontSize: 12, color: Colors.red.shade400),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    IconData icon,
    Function(String?) onChanged,
  ) {
    final uniqueItems = items.toSet().toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A237E),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonFormField<String>(
            value: uniqueItems.contains(value) ? value : null,
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: const Color(0xFF1A237E)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            items: uniqueItems.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item, overflow: TextOverflow.ellipsis, maxLines: 1),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildQRDisplayCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Active QR Code - Scan for Attendance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A237E),
              ),
            ),
            const SizedBox(height: 8),

            // Location info indicator (only added this)
            if (_currentPosition != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Location captured',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    '📚 $selectedCourse',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('📖 $selectedSubject'),
                  Text('👥 $selectedBatch | $selectedSemester'),
                  Text('📅 ${_formatDate(selectedDate)} | ⏰ $selectedTimeSlot'),
                  Text('👨‍🏫 $teacherName'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            RepaintBoundary(
              child: QrImageView(
                data: qrData,
                size: 250,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return Column(
                  children: [
                    LinearProgressIndicator(
                      value: _progressAnimation.value,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.orange,
                      ),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'QR Code refreshes in ${(_progressAnimation.value * 30).toInt()} seconds',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: generateQR,
              icon: const Icon(Icons.refresh),
              label: const Text('Regenerate QR'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1A237E),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  Widget _buildTeacherInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  teacherName.isEmpty ? "Teacher" : teacherName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  widget.userEmail,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (teacherDepartment.isNotEmpty)
                  Text(
                    teacherDepartment,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Active',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
