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
      } else if (teacherDepartment == 'Electrical Engineering' || teacherDepartment == 'EE') {
        courses = [
          'BSEE (Bachelor of Electrical Engineering) - 4 Years',
          'MSEE (Master of Electrical Engineering) - 2 Years',
          'PhD Electrical Engineering - 5 Years',
        ];
      } else if (teacherDepartment == 'Mechanical Engineering' || teacherDepartment == 'ME') {
        courses = [
          'BSME (Bachelor of Mechanical Engineering) - 4 Years',
          'MSME (Master of Mechanical Engineering) - 2 Years',
          'PhD Mechanical Engineering - 5 Years',
        ];
      } else if (teacherDepartment == 'Business Administration' || teacherDepartment == 'BBA') {
        courses = [
          'BBA (Bachelor of Business Administration) - 4 Years',
          'MBA (Master of Business Administration) - 2 Years',
          'PhD Management - 5 Years',
        ];
      } else if (teacherDepartment == 'Mathematics') {
        courses = [
          'BS Mathematics - 4 Years',
          'MS Mathematics - 2 Years',
          'PhD Mathematics - 5 Years',
        ];
      } else if (teacherDepartment == 'Physics') {
        courses = [
          'BS Physics - 4 Years',
          'MS Physics - 2 Years',
          'PhD Physics - 5 Years',
        ];
      } else if (teacherDepartment == 'Chemistry') {
        courses = [
          'BS Chemistry - 4 Years',
          'MS Chemistry - 2 Years',
          'PhD Chemistry - 5 Years',
        ];
      } else if (teacherDepartment == 'English Literature') {
        courses = [
          'BA English - 4 Years',
          'MA English - 2 Years',
          'PhD English - 5 Years',
        ];
      } else if (teacherDepartment == 'Economics') {
        courses = [
          'BS Economics - 4 Years',
          'MS Economics - 2 Years',
          'PhD Economics - 5 Years',
        ];
      } else if (teacherDepartment == 'Psychology') {
        courses = [
          'BS Psychology - 4 Years',
          'MS Psychology - 2 Years',
          'PhD Psychology - 5 Years',
        ];
      } else {
        courses = [
          'Bachelor Program - 4 Years',
          'Master Program - 2 Years',
          'Doctoral Program - 5 Years',
        ];
      }
      
      if (courses.isNotEmpty) selectedCourse = courses.first;
      
      // Generate batches based on selected course
      _generateBatches();
      
      // Generate semesters based on selected course
      _generateSemesters();
      
      // Generate ALL subjects based on selected course (not restricted by semester)
      await _loadAllSubjects();
      
      // Generate time slots
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
    
    if (selectedCourse.contains('Bachelor') || selectedCourse.contains('BSCS') || 
        selectedCourse.contains('BSSE') || selectedCourse.contains('BSIT') ||
        selectedCourse.contains('BBA') || selectedCourse.contains('BSEE') ||
        selectedCourse.contains('BSME')) {
      // 4-year bachelor program
      for (int i = 0; i < 4; i++) {
        int batchYear = currentYear - i;
        batches.add('Batch $batchYear - ${batchYear + 4}');
      }
    } else if (selectedCourse.contains('Master') || selectedCourse.contains('MSCS') || 
               selectedCourse.contains('MSSE') || selectedCourse.contains('MSIT') ||
               selectedCourse.contains('MBA') || selectedCourse.contains('MSEE') ||
               selectedCourse.contains('MSME')) {
      // 2-year master program
      for (int i = 0; i < 2; i++) {
        int batchYear = currentYear - i;
        batches.add('Batch $batchYear - ${batchYear + 2}');
      }
    } else if (selectedCourse.contains('PhD')) {
      // 5-year PhD program
      for (int i = 0; i < 5; i++) {
        int batchYear = currentYear - i;
        batches.add('Batch $batchYear - ${batchYear + 5}');
      }
    } else {
      // Default 4-year program
      for (int i = 0; i < 4; i++) {
        int batchYear = currentYear - i;
        batches.add('Batch $batchYear - ${batchYear + 4}');
      }
    }
  }

  void _generateSemesters() {
    semesters.clear();
    
    if (selectedCourse.contains('Bachelor') || selectedCourse.contains('BSCS') || 
        selectedCourse.contains('BSSE') || selectedCourse.contains('BSIT') ||
        selectedCourse.contains('BBA') || selectedCourse.contains('BSEE') ||
        selectedCourse.contains('BSME')) {
      // 8 semesters for 4-year bachelor
      for (int i = 1; i <= 8; i++) {
        semesters.add('Semester $i');
      }
    } else if (selectedCourse.contains('Master') || selectedCourse.contains('MSCS') || 
               selectedCourse.contains('MSSE') || selectedCourse.contains('MSIT') ||
               selectedCourse.contains('MBA') || selectedCourse.contains('MSEE') ||
               selectedCourse.contains('MSME')) {
      // 4 semesters for 2-year master
      for (int i = 1; i <= 4; i++) {
        semesters.add('Semester $i');
      }
    } else if (selectedCourse.contains('PhD')) {
      // 10 semesters for 5-year PhD
      for (int i = 1; i <= 10; i++) {
        semesters.add('Semester $i');
      }
    } else {
      // Default 8 semesters
      for (int i = 1; i <= 8; i++) {
        semesters.add('Semester $i');
      }
    }
  }

  Future<void> _loadAllSubjects() async {
    subjects.clear();
    
    // ALL subjects for each degree (not restricted by semester)
    if (teacherDepartment == 'Computer Science' || teacherDepartment == 'CS') {
      if (selectedCourse.contains('Bachelor') || selectedCourse.contains('BSCS')) {
        // ALL BSCS Subjects (Complete 4-year program)
        subjects = [
          // Semester 1
          'Programming Fundamentals',
          'Discrete Structures',
          'Calculus and Analytical Geometry',
          'English Composition',
          'Islamic Studies',
          'Introduction to ICT',
          // Semester 2
          'Object Oriented Programming',
          'Data Structures',
          'Linear Algebra',
          'Communication Skills',
          'Pakistan Studies',
          'Digital Logic Design',
          // Semester 3
          'Database Systems',
          'Operating Systems',
          'Probability and Statistics',
          'Software Engineering',
          'Computer Organization',
          'Multivariable Calculus',
          // Semester 4
          'Design and Analysis of Algorithms',
          'Theory of Automata',
          'Computer Networks',
          'Web Development',
          'Human Computer Interaction',
          'Differential Equations',
          // Semester 5
          'Artificial Intelligence',
          'Compiler Construction',
          'Network Security',
          'Mobile App Development',
          'Parallel and Distributed Computing',
          'Technical Writing',
          // Semester 6
          'Machine Learning',
          'Cloud Computing',
          'Digital Image Processing',
          'Big Data Analytics',
          'Entrepreneurship',
          'Research Methods',
          // Semester 7
          'Deep Learning',
          'Blockchain Technology',
          'Internet of Things',
          'Computer Vision',
          'Final Year Project - I',
          'Professional Practices',
          // Semester 8
          'Natural Language Processing',
          'Quantum Computing',
          'Augmented Reality',
          'DevOps',
          'Final Year Project - II',
          'Cyber Law and Ethics',
        ];
      } else if (selectedCourse.contains('Master') || selectedCourse.contains('MSCS')) {
        // ALL MSCS Subjects (Complete 2-year program)
        subjects = [
          'Advanced Algorithms',
          'Advanced Databases',
          'Advanced Operating Systems',
          'Research Methodology',
          'Advanced Software Engineering',
          'Advanced Machine Learning',
          'Advanced Computer Networks',
          'Big Data Analytics',
          'Cloud Infrastructure',
          'Thesis Part - I',
          'Advanced Artificial Intelligence',
          'Advanced Network Security',
          'Data Science',
          'Thesis Part - II',
          'Special Topics in CS',
          'Research Publication',
          'Thesis Defense',
        ];
      } else if (selectedCourse.contains('PhD')) {
        // ALL PhD Subjects
        subjects = [
          'Advanced Research Methods',
          'PhD Seminar I',
          'PhD Seminar II',
          'Advanced Topics in Computer Science',
          'Dissertation Research I',
          'Dissertation Research II',
          'Dissertation Research III',
          'Dissertation Defense',
          'Research Publication I',
          'Research Publication II',
        ];
      }
    } else if (teacherDepartment == 'Software Engineering' || teacherDepartment == 'SE') {
      if (selectedCourse.contains('Bachelor') || selectedCourse.contains('BSSE')) {
        // ALL BSSE Subjects (Complete 4-year program)
        subjects = [
          // Semester 1
          'Programming Fundamentals',
          'Discrete Structures',
          'Calculus',
          'English',
          'Islamic Studies',
          'Introduction to SE',
          // Semester 2
          'Object Oriented Programming',
          'Data Structures',
          'Linear Algebra',
          'Communication Skills',
          'Pakistan Studies',
          'Digital Logic Design',
          // Semester 3
          'Database Systems',
          'Operating Systems',
          'Software Requirements Engineering',
          'Software Design & Architecture',
          'Probability & Statistics',
          'Web Engineering',
          // Semester 4
          'Software Quality Assurance',
          'Software Project Management',
          'Computer Networks',
          'Human Computer Interaction',
          'Formal Methods',
          'Mobile App Development',
          // Semester 5
          'Software Construction',
          'Software Testing',
          'Agile Development',
          'DevOps',
          'Cloud Computing',
          'Technical Writing',
          // Semester 6
          'Software Metrics',
          'Software Reuse',
          'Component Based Development',
          'Enterprise Architecture',
          'Research Methods',
          'Entrepreneurship',
          // Semester 7
          'Software Evolution',
          'Secure Software Development',
          'Game Development',
          'Final Year Project - I',
          'Professional Practices',
          // Semester 8
          'Software Process Improvement',
          'Global Software Development',
          'Final Year Project - II',
          'Cyber Security',
        ];
      }
    } else if (teacherDepartment == 'Information Technology' || teacherDepartment == 'IT') {
      if (selectedCourse.contains('Bachelor') || selectedCourse.contains('BSIT')) {
        // ALL BSIT Subjects (Complete 4-year program)
        subjects = [
          // Semester 1
          'Introduction to IT',
          'Programming Fundamentals',
          'Discrete Mathematics',
          'English',
          'Islamic Studies',
          'Calculus',
          // Semester 2
          'Object Oriented Programming',
          'Data Structures',
          'Linear Algebra',
          'Communication Skills',
          'Pakistan Studies',
          'Digital Logic Design',
          // Semester 3
          'Database Systems',
          'Operating Systems',
          'Computer Networks',
          'Web Development',
          'Probability & Statistics',
          'Multimedia Systems',
          // Semester 4
          'Network Security',
          'E-Commerce',
          'System Analysis & Design',
          'Mobile Computing',
          'Human Computer Interaction',
          'Cloud Computing',
          // Semester 5
          'IT Project Management',
          'Digital Marketing',
          'Data Mining',
          'Internet of Things',
          'Technical Writing',
          'Information Security',
          // Semester 6
          'Big Data Analytics',
          'Social Media Analytics',
          'Business Intelligence',
          'IT Infrastructure',
          'Research Methods',
          'Entrepreneurship',
          // Semester 7
          'IT Governance',
          'IT Service Management',
          'Final Year Project - I',
          'Professional Practices',
          // Semester 8
          'IT Strategy',
          'Digital Transformation',
          'Final Year Project - II',
        ];
      }
    } else if (teacherDepartment == 'Electrical Engineering' || teacherDepartment == 'EE') {
      if (selectedCourse.contains('Bachelor') || selectedCourse.contains('BSEE')) {
        // ALL BSEE Subjects
        subjects = [
          'Circuit Analysis',
          'Electronics',
          'Digital Logic Design',
          'Signals and Systems',
          'Electromagnetic Theory',
          'Power Systems',
          'Control Systems',
          'Electrical Machines',
          'Microprocessors',
          'Communication Systems',
          'Power Electronics',
          'Renewable Energy Systems',
          'Embedded Systems',
          'Instrumentation',
          'Final Year Project',
        ];
      }
    } else if (teacherDepartment == 'Mechanical Engineering' || teacherDepartment == 'ME') {
      if (selectedCourse.contains('Bachelor') || selectedCourse.contains('BSME')) {
        // ALL BSME Subjects
        subjects = [
          'Engineering Mechanics',
          'Thermodynamics',
          'Fluid Mechanics',
          'Solid Mechanics',
          'Machine Design',
          'Manufacturing Processes',
          'Heat Transfer',
          'Dynamics',
          'Vibrations',
          'CAD/CAM',
          'Mechatronics',
          'Refrigeration',
          'Automobile Engineering',
          'Final Year Project',
        ];
      }
    } else if (teacherDepartment == 'Business Administration' || teacherDepartment == 'BBA') {
      if (selectedCourse.contains('Bachelor') || selectedCourse.contains('BBA')) {
        // ALL BBA Subjects
        subjects = [
          'Principles of Management',
          'Marketing Management',
          'Financial Accounting',
          'Business Mathematics',
          'Business Statistics',
          'Organizational Behavior',
          'Human Resource Management',
          'Business Law',
          'Economics',
          'Business Communication',
          'Strategic Management',
          'Entrepreneurship',
          'Supply Chain Management',
          'International Business',
          'Final Year Project',
        ];
      }
    } else if (teacherDepartment == 'Mathematics') {
      subjects = [
        'Calculus I, II, III',
        'Linear Algebra',
        'Abstract Algebra',
        'Real Analysis',
        'Complex Analysis',
        'Differential Equations',
        'Number Theory',
        'Topology',
        'Geometry',
        'Probability Theory',
        'Statistics',
        'Mathematical Modeling',
        'Numerical Analysis',
        'Operations Research',
        'Final Year Project',
      ];
    } else if (teacherDepartment == 'Physics') {
      subjects = [
        'Classical Mechanics',
        'Electromagnetism',
        'Quantum Mechanics',
        'Thermodynamics',
        'Statistical Physics',
        'Solid State Physics',
        'Nuclear Physics',
        'Particle Physics',
        'Astrophysics',
        'Optics',
        'Mathematical Physics',
        'Computational Physics',
        'Final Year Project',
      ];
    } else if (teacherDepartment == 'Chemistry') {
      subjects = [
        'Organic Chemistry',
        'Inorganic Chemistry',
        'Physical Chemistry',
        'Analytical Chemistry',
        'Biochemistry',
        'Environmental Chemistry',
        'Polymer Chemistry',
        'Medicinal Chemistry',
        'Industrial Chemistry',
        'Spectroscopy',
        'Chromatography',
        'Final Year Project',
      ];
    } else if (teacherDepartment == 'English Literature') {
      subjects = [
        'English Poetry',
        'English Drama',
        'English Novel',
        'Literary Criticism',
        'American Literature',
        'World Literature',
        'Linguistics',
        'Creative Writing',
        'Technical Writing',
        'Shakespeare Studies',
        'Postcolonial Literature',
        'Final Year Project',
      ];
    } else if (teacherDepartment == 'Economics') {
      subjects = [
        'Microeconomics',
        'Macroeconomics',
        'Econometrics',
        'Development Economics',
        'International Economics',
        'Public Finance',
        'Monetary Economics',
        'Labor Economics',
        'Environmental Economics',
        'Financial Economics',
        'Final Year Project',
      ];
    } else if (teacherDepartment == 'Psychology') {
      subjects = [
        'Introduction to Psychology',
        'Cognitive Psychology',
        'Developmental Psychology',
        'Social Psychology',
        'Abnormal Psychology',
        'Clinical Psychology',
        'Counseling Psychology',
        'Organizational Psychology',
        'Neuropsychology',
        'Research Methods',
        'Final Year Project',
      ];
    } else {
      // Generic subjects for other departments
      subjects = [
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
      ];
    }
    
    // Ensure subjects list is not empty
    if (subjects.isEmpty) {
      subjects = ['General Subject 1', 'General Subject 2', 'General Subject 3'];
    }
  }

  void _generateTimeSlots() {
    timeSlots = [
      '08:00 AM - 09:00 AM',
      '09:00 AM - 10:00 AM',
      '10:00 AM - 11:00 AM',
      '11:00 AM - 12:00 PM',
      '12:00 PM - 01:00 PM',
      '01:00 PM - 02:00 PM',
      '02:00 PM - 03:00 PM',
      '03:00 PM - 04:00 PM',
      '04:00 PM - 05:00 PM',
      '05:00 PM - 06:00 PM',
      '06:00 PM - 07:00 PM',
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
      });
    }
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
      // Create lecture info for QR code
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
        'lectureId': 'LEC_${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': DateTime.now().toIso8601String(),
        'expiry': DateTime.now().add(const Duration(seconds: 30)).toIso8601String(),
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
                  colors: [
                    Colors.blue.shade50,
                    Colors.white,
                  ],
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Teacher Info Card
                    _buildTeacherInfoCard(),
                    
                    const SizedBox(height: 20),
                    
                    // Lecture Details Card
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
                            
                            // Course Dropdown
                            _buildDropdown(
                              label: 'Course',
                              value: selectedCourse,
                              items: courses,
                              icon: Icons.school,
                              onChanged: (value) {
                                setState(() {
                                  selectedCourse = value!;
                                  isQrGenerated = false;
                                  qrData = "";
                                  _generateBatches();
                                  _generateSemesters();
                                  _loadAllSubjects();
                                });
                              },
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Batch Dropdown
                            _buildDropdown(
                              label: 'Batch',
                              value: selectedBatch,
                              items: batches,
                              icon: Icons.group,
                              onChanged: (value) {
                                setState(() {
                                  selectedBatch = value!;
                                  isQrGenerated = false;
                                  qrData = "";
                                });
                              },
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Semester Dropdown
                            _buildDropdown(
                              label: 'Semester',
                              value: selectedSemester,
                              items: semesters,
                              icon: Icons.grade,
                              onChanged: (value) {
                                setState(() {
                                  selectedSemester = value!;
                                  isQrGenerated = false;
                                  qrData = "";
                                });
                              },
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Subject Dropdown (ALL subjects of the degree)
                            _buildDropdown(
                              label: 'Subject',
                              value: selectedSubject,
                              items: subjects,
                              icon: Icons.menu_book,
                              onChanged: (value) {
                                setState(() {
                                  selectedSubject = value!;
                                  isQrGenerated = false;
                                  qrData = "";
                                });
                              },
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Date Picker
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
                                    Expanded(
                                      child: Text(
                                        'Date: ${_formatDate(selectedDate)}',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    const Icon(Icons.arrow_drop_down),
                                  ],
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Time Slot Dropdown
                            _buildDropdown(
                              label: 'Time Slot',
                              value: selectedTimeSlot,
                              items: timeSlots,
                              icon: Icons.access_time,
                              onChanged: (value) {
                                setState(() {
                                  selectedTimeSlot = value!;
                                  isQrGenerated = false;
                                  qrData = "";
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Generate QR Button
                    ElevatedButton.icon(
                      onPressed: generateQR,
                      icon: const Icon(Icons.qr_code),
                      label: const Text(
                        'Generate Attendance QR Code',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                    
                    // QR Code Display Section
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

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
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
        DropdownButtonFormField<String>(
          value: value.isEmpty ? null : value,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF1A237E)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          items: items.map((String item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildQRDisplayCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
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
              child: QrImageView(
                data: qrData,
                size: 250,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
            const SizedBox(height: 16),
            
            // Timer
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

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
                  teacherName.isEmpty ? "Teacher" : teacherName,
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
                if (teacherDepartment.isNotEmpty)
                  Text(
                    teacherDepartment,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
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