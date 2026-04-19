import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_attendence/screens/attendence_screen.dart';
import '../services/firestore_service.dart';

class StudentScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String userEmail;
  final Map<String, dynamic>? userData;

  const StudentScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.userData,
  });

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen>
    with SingleTickerProviderStateMixin {
  String scannedData = "Ready to scan";
  bool isScanned = false;
  bool isProcessing = false;
  MobileScannerController cameraController = MobileScannerController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  final firestoreService = FirestoreService();

  // Location variables
  Position? _currentPosition;
  String _currentAddress = "";
  bool _isLocationEnabled = false;
  bool _isLoadingLocation = false;
  bool _locationPermissionDenied = false;
  bool _isRequestingPermission = false;

  // Student info
  String studentName = "";
  String studentRollNo = "";
  String studentCourse = "";
  String studentBatch = "";
  String studentSemester = "";
  String studentDepartment = "";
  String studentPhone = "";
  String studentDob = "";
  bool isLoading = true;

  // Location tolerance in meters
  static const double LOCATION_TOLERANCE_METERS = 100.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
    _loadStudentInfo();
    
    // Delay permission request to ensure UI is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestLocationPermission();
    });
  }

  @override
  void dispose() {
    cameraController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    if (_isRequestingPermission) return;
    
    setState(() {
      _isRequestingPermission = true;
      scannedData = "📍 Requesting location permission...";
    });

    try {
      // First, check current status
      final status = await Permission.location.status;
      
      print('Current location permission status: $status');
      
      if (status.isGranted) {
        print('Location permission already granted');
        setState(() {
          _isLocationEnabled = true;
          _locationPermissionDenied = false;
          _isRequestingPermission = false;
        });
        await _getCurrentLocation();
      } else if (status.isDenied) {
        print('Location permission is denied, requesting...');
        setState(() {
          scannedData = "📍 Please allow location permission...";
        });
        
        // Request permission
        final result = await Permission.location.request();
        print('Permission request result: $result');
        
        if (result.isGranted) {
          print('Location permission granted');
          setState(() {
            _isLocationEnabled = true;
            _locationPermissionDenied = false;
            _isRequestingPermission = false;
          });
          await _getCurrentLocation();
        } else if (result.isDenied) {
          print('Location permission denied by user');
          setState(() {
            _isLocationEnabled = false;
            _locationPermissionDenied = true;
            _isRequestingPermission = false;
            scannedData = "⚠️ Location permission denied.\nTap the location icon in app bar to enable.";
          });
          
          // Show a snackbar explaining why permission is needed
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is needed to mark attendance. Please enable it.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else if (status.isPermanentlyDenied) {
        print('Location permission permanently denied');
        setState(() {
          _isLocationEnabled = false;
          _locationPermissionDenied = true;
          _isRequestingPermission = false;
          scannedData = "⚠️ Location permission permanently denied.\nPlease enable in settings.";
        });
        _showLocationSettingsDialog();
      } else if (status.isRestricted) {
        print('Location permission is restricted');
        setState(() {
          _isLocationEnabled = false;
          _locationPermissionDenied = true;
          _isRequestingPermission = false;
          scannedData = "⚠️ Location permission is restricted.";
        });
      }
    } catch (e) {
      print('Error requesting location permission: $e');
      setState(() {
        _isRequestingPermission = false;
        scannedData = "❌ Error requesting location permission.";
      });
    }
  }

  void _showLocationSettingsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'Location permission is required to mark attendance. '
          'Please enable location permission in settings to continue.\n\n'
          'Go to Settings → Apps → Your App → Permissions → Location → Allow',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
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

  Future<bool> _getCurrentLocation() async {
    if (!_isLocationEnabled) {
      print('Location not enabled, requesting permission first');
      await _requestLocationPermission();
      if (!_isLocationEnabled) return false;
    }
    
    setState(() {
      _isLoadingLocation = true;
      scannedData = "📍 Getting your location...";
    });

    try {
      // Check if location services are enabled on device
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable location services (GPS)'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        setState(() {
          _isLoadingLocation = false;
          scannedData = "⚠️ Please enable location services (GPS)";
        });
        return false;
      }

      // Check permission again
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        print('Permission denied, requesting...');
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Permission denied after request');
          setState(() {
            _isLoadingLocation = false;
            scannedData = "⚠️ Location permission denied";
          });
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Permission permanently denied');
        setState(() {
          _isLoadingLocation = false;
          scannedData = "⚠️ Location permission permanently denied";
        });
        _showLocationSettingsDialog();
        return false;
      }

      print('Getting current position...');
      // Get current position with timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      
      print('Got position: ${position.latitude}, ${position.longitude}');
      
      setState(() {
        _currentPosition = position;
      });

      // Get address from coordinates
      try {
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
          print('Got address: $_currentAddress');
        }
      } catch (e) {
        print('Error getting address: $e');
      }
      
      setState(() {
        _isLoadingLocation = false;
        scannedData = "✅ Location ready!\nYou can now scan QR code.";
      });
      
      // Show success message briefly
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !isProcessing && !isScanned) {
          setState(() {
            scannedData = "Ready to scan";
          });
        }
      });
      
      return true;
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().substring(0, 100)}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      setState(() {
        _isLoadingLocation = false;
        scannedData = "❌ Could not get location.\nMake sure GPS is enabled.";
      });
      return false;
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  Future<void> _loadStudentInfo() async {
    if (widget.userData != null && widget.userData!.isNotEmpty) {
      setState(() {
        studentName = widget.userData?['name'] ?? widget.userName;
        studentRollNo = widget.userData?['rollNo'] ?? '';
        studentCourse = widget.userData?['course'] ?? '';
        studentBatch = widget.userData?['batch'] ?? '';
        studentSemester = _normalizeSemesterForStorage(
          widget.userData?['semester'] ?? '',
        );
        studentDepartment = widget.userData?['department'] ?? '';
        studentPhone = widget.userData?['phone'] ?? '';
        studentDob = widget.userData?['dob'] ?? '';
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
            studentName = doc['name'] ?? widget.userName;
            studentRollNo = doc['rollNo'] ?? '';
            studentCourse = doc['course'] ?? '';
            studentBatch = doc['batch'] ?? '';
            studentSemester = _normalizeSemesterForStorage(
              doc['semester'] ?? '',
            );
            studentDepartment = doc['department'] ?? '';
            studentPhone = doc['phone'] ?? '';
            studentDob = doc['dob'] ?? '';
            isLoading = false;
          });
        } else {
          setState(() {
            studentName = widget.userName;
            isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          studentName = widget.userName;
          isLoading = false;
        });
      }
    }
  }

  String _normalizeSemesterForStorage(String semester) {
    if (semester.isEmpty) return '';

    final numbers = RegExp(r'\d+').firstMatch(semester);
    if (numbers != null) {
      return 'Semester ${numbers.group(0)}';
    }

    final romanMap = {
      'I': '1',
      'II': '2',
      'III': '3',
      'IV': '4',
      'V': '5',
      'VI': '6',
      'VII': '7',
      'VIII': '8',
    };
    for (var entry in romanMap.entries) {
      if (semester.toUpperCase().contains(entry.key)) {
        return 'Semester ${entry.value}';
      }
    }

    return semester;
  }

  String _normalizeSemester(String semesterStr) {
    if (semesterStr.isEmpty) return '';

    final numbers = RegExp(r'\d+').allMatches(semesterStr);
    if (numbers.isNotEmpty) {
      return numbers.first.group(0)!;
    }

    final romanMap = {
      'I': '1',
      'II': '2',
      'III': '3',
      'IV': '4',
      'V': '5',
      'VI': '6',
      'VII': '7',
      'VIII': '8',
    };
    for (var entry in romanMap.entries) {
      if (semesterStr.toUpperCase().contains(entry.key)) {
        return entry.value;
      }
    }

    return semesterStr;
  }

  bool _isCourseMatch(String studentCourse, String qrCourse) {
    if (studentCourse.isEmpty || qrCourse.isEmpty) return true;

    final studentProgram = studentCourse.split(' ')[0].toUpperCase();
    final qrProgram = qrCourse.split(' ')[0].toUpperCase();

    return studentProgram == qrProgram;
  }

  bool _isBatchMatch(String studentBatch, String qrBatch) {
    if (studentBatch.isEmpty || qrBatch.isEmpty) return true;

    final studentYear = RegExp(r'\d{4}').firstMatch(studentBatch)?.group(0);
    final qrYear = RegExp(r'\d{4}').firstMatch(qrBatch)?.group(0);

    if (studentYear != null && qrYear != null) {
      return studentYear == qrYear;
    }

    return studentBatch == qrBatch;
  }

  bool _isSemesterMatch(String studentSemester, String qrSemester) {
    if (studentSemester.isEmpty || qrSemester.isEmpty) return true;

    final studentSemNum = _normalizeSemester(studentSemester);
    final qrSemNum = _normalizeSemester(qrSemester);

    return studentSemNum == qrSemNum;
  }

  void _showStudentInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.person, color: Color(0xFF1A237E), size: 28),
            const SizedBox(width: 10),
            const Text(
              'Student Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A237E),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A237E), Color(0xFF283593)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.school,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildInfoRow(Icons.person, 'Full Name', studentName),
              const Divider(),
              _buildInfoRow(Icons.email, 'Email', widget.userEmail),
              const Divider(),
              if (studentRollNo.isNotEmpty)
                _buildInfoRow(Icons.numbers, 'Roll Number', studentRollNo),
              if (studentCourse.isNotEmpty)
                _buildInfoRow(Icons.school, 'Program', studentCourse),
              if (studentBatch.isNotEmpty)
                _buildInfoRow(Icons.group, 'Batch', studentBatch),
              if (studentSemester.isNotEmpty)
                _buildInfoRow(Icons.grade, 'Semester', studentSemester),
              if (studentDepartment.isNotEmpty)
                _buildInfoRow(Icons.business, 'Department', studentDepartment),
              if (studentPhone.isNotEmpty)
                _buildInfoRow(Icons.phone, 'Phone', studentPhone),
              if (studentDob.isNotEmpty)
                _buildInfoRow(
                  Icons.cake,
                  'Date of Birth',
                  _formatDateString(studentDob),
                ),
              const Divider(),
              _buildInfoRow(
                Icons.qr_code,
                'Student ID',
                widget.userId.substring(0, 12) + '...',
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1A237E),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _navigateToAttendanceHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentAttendanceScreen(
          studentId: widget.userId,
          studentName: studentName,
          studentBatch: studentBatch,
          studentCourse: studentCourse,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF1A237E)),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not provided' : value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateString(String dateString) {
    if (dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  void _showAlreadyMarkedDialog(String subject, String teacherName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange, size: 32),
            const SizedBox(width: 10),
            const Text('Already Marked!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('You have already marked attendance for:'),
            const SizedBox(height: 8),
            Text(
              '📖 Subject: $subject',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('👨‍🏫 Teacher: $teacherName'),
            const SizedBox(height: 8),
            const Text(
              'Duplicate attendance is not allowed.',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLocationMismatchDialog(double distance, String qrAddress, String studentAddress) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.location_off, color: Colors.red, size: 32),
            const SizedBox(width: 10),
            const Text('Location Mismatch!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You must be in the lecture location to mark attendance.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📍 Distance: ${distance.toStringAsFixed(0)} meters away',
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Required: Within ${LOCATION_TOLERANCE_METERS.toStringAsFixed(0)} meters',
                    style: TextStyle(color: Colors.orange.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('Lecture Location:'),
            Text(
              qrAddress.isNotEmpty ? qrAddress : 'Unknown location',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text('Your Location:'),
            Text(
              studentAddress.isNotEmpty ? studentAddress : 'Unknown location',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void onDetect(BarcodeCapture capture) async {
    if (isScanned || isProcessing) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        scannedData = "❌ Not logged in";
      });
      return;
    }

    // Check if location permission is denied
    if (_locationPermissionDenied) {
      setState(() {
        scannedData = "❌ Location permission denied.\nTap the location icon to enable.";
        isProcessing = false;
      });
      _showLocationSettingsDialog();
      return;
    }

    // First, get current location if not available
    if (_currentPosition == null) {
      setState(() {
        scannedData = "📍 Getting your location...";
        isProcessing = true;
      });
      
      final locationSuccess = await _getCurrentLocation();
      if (!locationSuccess) {
        setState(() {
          scannedData = "❌ Unable to get your location.\nPlease enable location services.";
          isProcessing = false;
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) resetScanner();
        });
        return;
      }
      
      setState(() {
        isProcessing = false;
      });
    }

    final List<Barcode> barcodes = capture.barcodes;

    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;

      if (code != null) {
        setState(() {
          isProcessing = true;
          scannedData = "⏳ Verifying location and processing...";
        });

        try {
          final decoded = jsonDecode(code);

          final course = decoded['course'] ?? '';
          final batch = decoded['batch'] ?? '';
          final semester = decoded['semester'] ?? '';
          final subject = decoded['subject'] ?? '';
          final date = decoded['date'] ?? '';
          final timeSlot = decoded['timeSlot'] ?? '';
          final teacherId = decoded['teacherId'] ?? '';
          final teacherName = decoded['teacherName'] ?? '';
          final department = decoded['department'] ?? '';
          final lectureId = decoded['lectureId'] ?? '';
          final expiry = decoded['expiry'] ?? '';
          final qrLocation = decoded['location'];

          // Check expiry
          if (expiry != null && expiry.isNotEmpty) {
            final expiryTime = DateTime.parse(expiry);
            final now = DateTime.now();

            if (now.isAfter(expiryTime)) {
              setState(() {
                scannedData = "❌ QR Code Expired!\nThis QR code is no longer valid.";
                isProcessing = false;
              });
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) resetScanner();
              });
              return;
            }
          }

          // Check location if QR code contains location data
          if (qrLocation != null && _currentPosition != null) {
            final qrLat = qrLocation['latitude'] as double;
            final qrLon = qrLocation['longitude'] as double;
            
            final distance = _calculateDistance(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              qrLat,
              qrLon,
            );

            if (distance > LOCATION_TOLERANCE_METERS) {
              final qrAddress = qrLocation['address'] ?? '';
              setState(() {
                scannedData = "❌ Location mismatch!\nYou are ${distance.toStringAsFixed(0)} meters away from the lecture location.";
                isProcessing = false;
              });
              
              _showLocationMismatchDialog(distance, qrAddress, _currentAddress);
              
              Future.delayed(const Duration(seconds: 4), () {
                if (mounted) resetScanner();
              });
              return;
            }
          } else if (qrLocation == null) {
            setState(() {
              scannedData = "❌ Invalid QR Code!\nThis QR code doesn't contain location data.";
              isProcessing = false;
            });
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) resetScanner();
            });
            return;
          }

          // Course validation
          if (studentCourse.isNotEmpty && course.isNotEmpty) {
            if (!_isCourseMatch(studentCourse, course)) {
              setState(() {
                scannedData = "❌ This lecture is not for your course!\nYour Course: ${studentCourse.split(' ')[0]}\nLecture Course: ${course.split(' ')[0]}";
                isProcessing = false;
              });
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) resetScanner();
              });
              return;
            }
          }

          // Batch validation
          if (studentBatch.isNotEmpty && batch.isNotEmpty) {
            if (!_isBatchMatch(studentBatch, batch)) {
              setState(() {
                scannedData = "❌ This lecture is not for your batch!\nYour Batch: $studentBatch\nLecture Batch: $batch";
                isProcessing = false;
              });
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) resetScanner();
              });
              return;
            }
          }

          // Semester validation
          if (studentSemester.isNotEmpty && semester.isNotEmpty) {
            if (!_isSemesterMatch(studentSemester, semester)) {
              setState(() {
                scannedData = "❌ This lecture is not for your semester!\nYour Semester: $studentSemester\nLecture Semester: $semester";
                isProcessing = false;
              });
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) resetScanner();
              });
              return;
            }
          }

          final studentId = widget.userId;

          // Check if already marked attendance
          final hasAttended = await firestoreService.hasStudentAttendedLecture(
            studentId: studentId,
            lectureId: lectureId,
          );

          if (hasAttended) {
            setState(() {
              scannedData = "⚠️ Attendance already marked!\nStudent: $studentName\nSubject: $subject";
              isProcessing = false;
            });
            _showAlreadyMarkedDialog(subject, teacherName);
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) resetScanner();
            });
            return;
          }

          // Mark attendance with location data
          await firestoreService.markAttendance(
            classId: lectureId,
            lectureId: lectureId,
            studentId: studentId,
            additionalData: {
              'course': course,
              'batch': batch,
              'semester': semester,
              'subject': subject,
              'date': date,
              'timeSlot': timeSlot,
              'teacherId': teacherId,
              'teacherName': teacherName,
              'department': department,
              'studentName': studentName,
              'studentRollNo': studentRollNo,
              'studentCourse': studentCourse,
              'studentBatch': studentBatch,
              'studentSemester': studentSemester,
              'studentLocation': {
                'latitude': _currentPosition!.latitude,
                'longitude': _currentPosition!.longitude,
                'address': _currentAddress,
              },
              'qrLocation': qrLocation,
              'distanceFromLecture': qrLocation != null ? _calculateDistance(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                qrLocation['latitude'] as double,
                qrLocation['longitude'] as double,
              ) : null,
            },
          );

          setState(() {
            scannedData = "✅ Attendance Marked Successfully!\n📚 Course: ${course.split(' ')[0]}\n📖 Subject: $subject\n👨‍🏫 Teacher: $teacherName\n📍 Location verified";
            isScanned = true;
            isProcessing = false;
          });

          _showSuccessDialog(
            course: course,
            batch: batch,
            semester: semester,
            subject: subject,
            date: date,
            timeSlot: timeSlot,
            teacherName: teacherName,
            distance: qrLocation != null ? _calculateDistance(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              qrLocation['latitude'] as double,
              qrLocation['longitude'] as double,
            ) : null,
          );
        } catch (e) {
          print('Error processing QR: $e');
          setState(() {
            scannedData = "❌ Error: Invalid QR Code format";
            isProcessing = false;
          });
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) resetScanner();
          });
        }
        break;
      }
    }
  }

  void resetScanner() {
    setState(() {
      isScanned = false;
      isProcessing = false;
      scannedData = "Ready to scan";
    });
  }

  void _showSuccessDialog({
    required String course,
    required String batch,
    required String semester,
    required String subject,
    required String date,
    required String timeSlot,
    required String teacherName,
    double? distance,
  }) {
    String formattedDate = "Today";
    if (date.isNotEmpty) {
      try {
        final dateTime = DateTime.parse(date);
        formattedDate = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      } catch (e) {
        formattedDate = date;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 32),
            const SizedBox(width: 10),
            const Text('Attendance Marked!'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lecture Details:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('📚 Course: ${course.split(' ')[0]}'),
                    Text('📖 Subject: $subject'),
                    Text('👨‍🏫 Teacher: $teacherName'),
                    Text('👥 Batch: $batch | Semester: $semester'),
                    Text('📅 Date: $formattedDate'),
                    Text('⏰ Time: $timeSlot'),
                    if (distance != null)
                      Text(
                        '📍 Distance from lecture: ${distance.toStringAsFixed(0)} meters',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Student Details:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('👨‍🎓 Name: $studentName'),
                    if (studentRollNo.isNotEmpty)
                      Text('🎫 Roll No: $studentRollNo'),
                    if (studentCourse.isNotEmpty)
                      Text('📚 Program: $studentCourse'),
                    if (studentBatch.isNotEmpty)
                      Text('👥 Batch: $studentBatch'),
                    if (studentSemester.isNotEmpty)
                      Text('📖 Semester: $studentSemester'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_currentAddress.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Location Details:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('📍 ${_currentAddress.split(',').first}'),
                      Text(
                        _currentAddress,
                        style: const TextStyle(fontSize: 11),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'Time: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              resetScanner();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Manual refresh location method
  Future<void> _refreshLocation() async {
    setState(() {
      _currentPosition = null;
      _currentAddress = "";
    });
    await _requestLocationPermission();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Location status indicator - Tappable to refresh
          if (_currentPosition != null)
            GestureDetector(
              onTap: _refreshLocation,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.green.shade300),
                    const SizedBox(width: 4),
                    Text(
                      'Location OK',
                      style: TextStyle(fontSize: 12, color: Colors.green.shade300),
                    ),
                  ],
                ),
              ),
            ),
          if (_locationPermissionDenied)
            GestureDetector(
              onTap: _requestLocationPermission,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_off, size: 16, color: Colors.red.shade300),
                    const SizedBox(width: 4),
                    Text(
                      'Tap to enable',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade300),
                    ),
                  ],
                ),
              ),
            ),
          if (_isLoadingLocation)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _navigateToAttendanceHistory,
            tooltip: 'Attendance History',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showStudentInfoDialog,
            tooltip: 'Student Information',
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              resetScanner();
              setState(() {
                cameraController.start();
              });
            },
            tooltip: 'Scan QR Code',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Student Info Card
                GestureDetector(
                  onTap: _showStudentInfoDialog,
                  child: Container(
                    margin: const EdgeInsets.all(16),
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
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                studentName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                widget.userEmail,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                              if (studentRollNo.isNotEmpty)
                                Text(
                                  'Roll No: $studentRollNo',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14,
                                  ),
                                ),
                              if (studentCourse.isNotEmpty)
                                Text(
                                  studentCourse,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Student',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white70),
                      ],
                    ),
                  ),
                ),

                // Scanner Section Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.qr_code_scanner,
                        color: const Color(0xFF1A237E),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Scan QR Code',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Scanner View
                Expanded(
                  flex: 4,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          MobileScanner(
                            controller: cameraController,
                            onDetect: onDetect,
                          ),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      child: Container(
                                        width: 30,
                                        height: 30,
                                        decoration: const BoxDecoration(
                                          border: Border(
                                            top: BorderSide(
                                              color: Colors.white,
                                              width: 3,
                                            ),
                                            left: BorderSide(
                                              color: Colors.white,
                                              width: 3,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Container(
                                        width: 30,
                                        height: 30,
                                        decoration: const BoxDecoration(
                                          border: Border(
                                            top: BorderSide(
                                              color: Colors.white,
                                              width: 3,
                                            ),
                                            right: BorderSide(
                                              color: Colors.white,
                                              width: 3,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      child: Container(
                                        width: 30,
                                        height: 30,
                                        decoration: const BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Colors.white,
                                              width: 3,
                                            ),
                                            left: BorderSide(
                                              color: Colors.white,
                                              width: 3,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        width: 30,
                                        height: 30,
                                        decoration: const BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Colors.white,
                                              width: 3,
                                            ),
                                            right: BorderSide(
                                              color: Colors.white,
                                              width: 3,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (isProcessing)
                            Container(
                              color: Colors.black.withOpacity(0.7),
                              child: const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text(
                                      'Processing...',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Status Card
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: ScaleTransition(
                              scale: _scaleAnimation,
                              child: Icon(
                                scannedData.contains('✅')
                                    ? Icons.check_circle
                                    : scannedData.contains('❌') ||
                                          scannedData.contains('⚠️')
                                    ? Icons.error_outline
                                    : Icons.qr_code_scanner,
                                size: 50,
                                color: scannedData.contains('✅')
                                    ? Colors.green
                                    : scannedData.contains('❌') ||
                                          scannedData.contains('⚠️')
                                    ? Colors.red
                                    : const Color(0xFF1A237E),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            scannedData,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: scannedData.contains('Successfully')
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: scannedData.contains('✅')
                                  ? Colors.green.shade700
                                  : scannedData.contains('❌') ||
                                        scannedData.contains('⚠️')
                                  ? Colors.red.shade700
                                  : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (isScanned ||
                              scannedData.contains('❌') ||
                              scannedData.contains('⚠️'))
                            ElevatedButton.icon(
                              onPressed: resetScanner,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Scan Again'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A237E),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          if (_isLoadingLocation)
                            const Padding(
                              padding: EdgeInsets.only(top: 16),
                              child: Text(
                                'Getting location...',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            cameraController.toggleTorch();
          });
        },
        backgroundColor: const Color(0xFF1A237E),
        child: const Icon(Icons.flash_on),
      ),
    );
  }
}