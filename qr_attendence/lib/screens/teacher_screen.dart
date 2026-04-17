import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/qr_service.dart';

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

class _TeacherScreenState extends State<TeacherScreen> with SingleTickerProviderStateMixin {
  String qrData = "";
  Timer? timer;
  bool isLoading = true;
  String teacherName = "";
  String teacherDepartment = "";
  int remainingSeconds = 30;
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  
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
    _progressAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_animationController);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTeacherData();
    });
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
      if (teacherDepartment == 'Computer Science' || teacherDepartment == 'CS') {
        courses = [
          'BSCS (Bachelor of Computer Science) - 4 Years',
          'MSCS (Master of Computer Science) - 2 Years',
          'PhD Computer Science - 5 Years',
        ];
      } else if (teacherDepartment == 'Software Engineering' || teacherDepartment == 'SE') {
        courses = [
          'BSSE (Bachelor of Software Engineering) - 4 Years',
          'MSSE (Master of Software Engineering) - 2 Years',
          'PhD Software Engineering - 5 Years',
        ];
      } else if (teacherDepartment == 'Information Technology' || teacherDepartment == 'IT') {
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
    batches.clear();
    
    if (selectedCourse.contains('Bachelor')) {
      for (int i = 0; i < 4; i++) {
        int batchYear = currentYear - i;
        batches.add('Batch $batchYear - ${batchYear + 4}');
      }
    } else if (selectedCourse.contains('Master')) {
      for (int i = 0; i < 2; i++) {
        int batchYear = currentYear - i;
        batches.add('Batch $batchYear - ${batchYear + 2}');
      }
    } else if (selectedCourse.contains('PhD')) {
      for (int i = 0; i < 5; i++) {
        int batchYear = currentYear - i;
        batches.add('Batch $batchYear - ${batchYear + 5}');
      }
    } else {
      for (int i = 0; i < 4; i++) {
        int batchYear = currentYear - i;
        batches.add('Batch $batchYear - ${batchYear + 4}');
      }
    }
  }

  void _generateSemesters() {
    semesters.clear();
    
    if (selectedCourse.contains('Bachelor')) {
      for (int i = 1; i <= 8; i++) {
        semesters.add('Semester $i');
      }
    } else if (selectedCourse.contains('Master')) {
      for (int i = 1; i <= 4; i++) {
        semesters.add('Semester $i');
      }
    } else if (selectedCourse.contains('PhD')) {
      for (int i = 1; i <= 10; i++) {
        semesters.add('Semester $i');
      }
    } else {
      for (int i = 1; i <= 8; i++) {
        semesters.add('Semester $i');
      }
    }
  }

  Future<void> _loadAllSubjects() async {
    subjects.clear();
    
    if (teacherDepartment == 'Computer Science' || teacherDepartment == 'CS') {
      if (selectedCourse.contains('Bachelor')) {
        subjects = [
          'Programming Fundamentals', 'Object Oriented Programming', 'Data Structures',
          'Database Systems', 'Operating Systems', 'Computer Networks',
          'Software Engineering', 'Artificial Intelligence', 'Machine Learning',
          'Web Development', 'Mobile App Development', 'Cloud Computing',
          'Network Security', 'Digital Image Processing', 'Big Data Analytics',
          'Final Year Project',
        ];
      } else if (selectedCourse.contains('Master')) {
        subjects = [
          'Advanced Algorithms', 'Advanced Databases', 'Research Methodology',
          'Advanced Machine Learning', 'Big Data Analytics', 'Cloud Computing',
          'Network Security', 'Data Science', 'Thesis',
        ];
      } else {
        subjects = [
          'Advanced Research Methods', 'PhD Seminar', 'Dissertation Research',
          'Advanced Topics', 'Research Publication',
        ];
      }
    } else {
      subjects = ['Subject 1', 'Subject 2', 'Subject 3', 'Subject 4', 'Subject 5'];
    }
  }

  void _generateTimeSlots() {
    timeSlots = [
      '08:00 AM - 09:00 AM', '09:00 AM - 10:00 AM', '10:00 AM - 11:00 AM',
      '11:00 AM - 12:00 PM', '12:00 PM - 01:00 PM', '01:00 PM - 02:00 PM',
      '02:00 PM - 03:00 PM', '03:00 PM - 04:00 PM', '04:00 PM - 05:00 PM',
    ];
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

  void generateQR() {
    if (selectedCourse.isEmpty || selectedBatch.isEmpty || selectedSemester.isEmpty || 
        selectedSubject.isEmpty || selectedTimeSlot.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all lecture details first!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    try {
      // Generate a persistent lectureId for this session if it doesn't exist
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
        'lectureId': currentLectureId, // Same lectureId for the whole session
        'timestamp': now.toIso8601String(),
        'expiry': now.add(const Duration(seconds: 30)).toIso8601String(),
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
            content: Text('QR Code Generated for "$selectedSubject"'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error generating QR: $e');
      if (mounted && !isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating QR: $e')),
        );
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
                    
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.class_, color: Color(0xFF1A237E)),
                                SizedBox(width: 10),
                                Text('Lecture Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            _buildDropdown('Course', selectedCourse, courses, Icons.school, (value) {
                              setState(() {
                                selectedCourse = value!;
                                isQrGenerated = false;
                                qrData = "";
                                _resetLectureSession();
                                _generateBatches();
                                _generateSemesters();
                                _loadAllSubjects();
                              });
                            }),
                            const SizedBox(height: 16),
                            
                            _buildDropdown('Batch', selectedBatch, batches, Icons.group, (value) {
                              setState(() {
                                selectedBatch = value!;
                                isQrGenerated = false;
                                qrData = "";
                                _resetLectureSession();
                              });
                            }),
                            const SizedBox(height: 16),
                            
                            _buildDropdown('Semester', selectedSemester, semesters, Icons.grade, (value) {
                              setState(() {
                                selectedSemester = value!;
                                isQrGenerated = false;
                                qrData = "";
                                _resetLectureSession();
                              });
                            }),
                            const SizedBox(height: 16),
                            
                            _buildDropdown('Subject', selectedSubject, subjects, Icons.menu_book, (value) {
                              setState(() {
                                selectedSubject = value!;
                                isQrGenerated = false;
                                qrData = "";
                                _resetLectureSession();
                              });
                            }),
                            const SizedBox(height: 16),
                            
                            InkWell(
                              onTap: _selectDate,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, color: Color(0xFF1A237E)),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text('Date: ${_formatDate(selectedDate)}', style: const TextStyle(fontSize: 16))),
                                    const Icon(Icons.arrow_drop_down),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            _buildDropdown('Time Slot', selectedTimeSlot, timeSlots, Icons.access_time, (value) {
                              setState(() {
                                selectedTimeSlot = value!;
                                isQrGenerated = false;
                                qrData = "";
                                _resetLectureSession();
                              });
                            }),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    ElevatedButton.icon(
                      onPressed: generateQR,
                      icon: const Icon(Icons.qr_code),
                      label: const Text('Generate Attendance QR Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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

  Widget _buildDropdown(String label, String value, List<String> items, IconData icon, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A237E))),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value.isEmpty ? null : value,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF1A237E)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          items: items.map((String item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
          onChanged: onChanged,
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
            const Text('Active QR Code - Scan for Attendance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: [
                  Text('📚 $selectedCourse', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('📖 $selectedSubject'),
                  Text('👥 $selectedBatch | $selectedSemester'),
                  Text('📅 ${_formatDate(selectedDate)} | ⏰ $selectedTimeSlot'),
                  Text('👨‍🏫 $teacherName'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            RepaintBoundary(
              child: QrImageView(data: qrData, size: 250, backgroundColor: Colors.white, errorCorrectionLevel: QrErrorCorrectLevel.M),
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
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Text('QR Code refreshes in ${(_progressAnimation.value * 30).toInt()} seconds', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF283593)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.person, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(teacherName.isEmpty ? "Teacher" : teacherName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(widget.userEmail, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                if (teacherDepartment.isNotEmpty) Text(teacherDepartment, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(20)),
            child: const Text('Active', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}