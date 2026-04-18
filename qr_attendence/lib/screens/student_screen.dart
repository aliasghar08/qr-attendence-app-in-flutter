import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  }

  @override
  void dispose() {
    cameraController.dispose();
    _animationController.dispose();
    super.dispose();
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

  // NEW: Navigate to detailed attendance history screen
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

  // Keep the old method for backward compatibility but redirect to new screen
  void _showAttendanceHistory() async {
    // Navigate to the detailed attendance screen instead of showing dialog
    _navigateToAttendanceHistory();
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

  void onDetect(BarcodeCapture capture) async {
    if (isScanned || isProcessing) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        scannedData = "❌ Not logged in";
      });
      return;
    }

    final List<Barcode> barcodes = capture.barcodes;

    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;

      if (code != null) {
        setState(() {
          isProcessing = true;
          scannedData = "⏳ Processing...";
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

          if (expiry != null && expiry.isNotEmpty) {
            final expiryTime = DateTime.parse(expiry);
            final now = DateTime.now();

            if (now.isAfter(expiryTime)) {
              setState(() {
                scannedData =
                    "❌ QR Code Expired!\nThis QR code is no longer valid.";
                isProcessing = false;
              });

              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) resetScanner();
              });
              return;
            }
          }

          if (studentCourse.isNotEmpty && course.isNotEmpty) {
            if (!_isCourseMatch(studentCourse, course)) {
              setState(() {
                scannedData =
                    "❌ This lecture is not for your course!\n"
                    "Your Course: ${studentCourse.split(' ')[0]}\n"
                    "Lecture Course: ${course.split(' ')[0]}";
                isProcessing = false;
              });

              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) resetScanner();
              });
              return;
            }
          }

          if (studentBatch.isNotEmpty && batch.isNotEmpty) {
            if (!_isBatchMatch(studentBatch, batch)) {
              setState(() {
                scannedData =
                    "❌ This lecture is not for your batch!\n"
                    "Your Batch: $studentBatch\n"
                    "Lecture Batch: $batch";
                isProcessing = false;
              });

              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) resetScanner();
              });
              return;
            }
          }

          if (studentSemester.isNotEmpty && semester.isNotEmpty) {
            if (!_isSemesterMatch(studentSemester, semester)) {
              setState(() {
                scannedData =
                    "❌ This lecture is not for your semester!\n"
                    "Your Semester: $studentSemester\n"
                    "Lecture Semester: $semester";
                isProcessing = false;
              });

              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) resetScanner();
              });
              return;
            }
          }

          final studentId = widget.userId;

          // Check if already marked attendance using the dedicated method
          final hasAttended = await firestoreService.hasStudentAttendedLecture(
            studentId: studentId,
            lectureId: lectureId,
          );

          if (hasAttended) {
            setState(() {
              scannedData =
                  "⚠️ Attendance already marked!\n"
                  "Student: $studentName\n"
                  "Subject: $subject\n"
                  "You have already marked attendance for this lecture.";
              isProcessing = false;
            });

            _showAlreadyMarkedDialog(subject, teacherName);

            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) resetScanner();
            });
            return;
          }

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
            },
          );

          setState(() {
            scannedData =
                "✅ Attendance Marked Successfully!\n"
                "📚 Course: ${course.split(' ')[0]}\n"
                "📖 Subject: $subject\n"
                "👨‍🏫 Teacher: $teacherName\n"
                "⏰ Time: $timeSlot";
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
          // NEW: Navigation icon to attendance history screen
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
