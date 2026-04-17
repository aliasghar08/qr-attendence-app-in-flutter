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

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    );
    _progressAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_animationController);
    
    // Load data after initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTeacherData();
    });
  }

  Future<void> _loadTeacherData() async {
    // Use passed data if available, otherwise fetch from Firestore
    if (widget.userData != null && widget.userData!.isNotEmpty) {
      setState(() {
        teacherName = widget.userData?['name'] ?? widget.userName;
        teacherDepartment = widget.userData?['department'] ?? '';
        isLoading = false;
      });
      generateQR();
      _startAutoRefresh();
    } else {
      // Fallback to fetching from Firestore if data not passed
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get();
        
        if (doc.exists) {
          setState(() {
            teacherName = doc['name'] ?? widget.userName;
            teacherDepartment = doc['department'] ?? '';
            isLoading = false;
          });
        } else {
          setState(() {
            teacherName = widget.userName;
            isLoading = false;
          });
        }
        
        generateQR();
        _startAutoRefresh();
        
      } catch (e) {
        print('Error loading teacher data: $e');
        setState(() {
          teacherName = widget.userName;
          isLoading = false;
        });
        // Still try to generate QR even if teacher data fails
        generateQR();
        _startAutoRefresh();
      }
    }
  }

  void _startAutoRefresh() {
    // Cancel existing timer if any
    timer?.cancel();
    
    // Set up timer to refresh every 30 seconds
    timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        generateQR();
        // Reset animation
        _animationController.reset();
        _animationController.forward();
      }
    });
    
    // Start progress animation
    _animationController.forward();
  }

  void generateQR() {
    try {
      // Generate QR data with teacher-specific info
      final generatedData = QRService.generateQRData(
        teacherId: widget.userId,
        teacherName: teacherName,
        className: teacherDepartment,
      );
      
      // Check if generated data is not null and not empty
      if (generatedData.isEmpty) {
        throw Exception("Generated QR data is empty");
      }
      
      setState(() {
        qrData = generatedData;
        remainingSeconds = 30;
      });
      
      // Reset the timer when manually generating QR
      // This will restart the 30-second countdown
      if (!isLoading) {
        _resetTimer();
      }
      
      // Only show SnackBar if mounted and not during initial load
      if (mounted && !isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR Code Generated Successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('Error generating QR: $e');
      setState(() {
        // Set a default QR data as fallback with teacher ID
        qrData = '{"classId":"${widget.userId.substring(0, 8)}","lectureId":"Lec1","teacherId":"${widget.userId}","timestamp":"${DateTime.now().toIso8601String()}"}';
      });
      
      // Only show error SnackBar if mounted and not during initial load
      if (mounted && !isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating QR: $e')),
        );
      }
    }
  }

  void _resetTimer() {
    // Cancel existing timer
    timer?.cancel();
    
    // Reset animation
    _animationController.reset();
    _animationController.forward();
    
    // Start new timer
    timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        generateQR();
        _animationController.reset();
        _animationController.forward();
      }
    });
  }

  void _showQRDetails() {
    // Parse current QR data to show details
    Map<String, dynamic> qrDetails = {};
    try {
      qrDetails = Map<String, dynamic>.from(jsonDecode(qrData));
    } catch (e) {
      qrDetails = {
        'classId': widget.userId.substring(0, 8),
        'lectureId': 'Lec1',
        'teacherId': widget.userId,
      };
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('QR Code Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This QR code contains:'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📚 Class: ${qrDetails['className'] ?? teacherDepartment}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text('📖 Lecture ID: ${qrDetails['lectureId'] ?? 'Lec1'}'),
                  const SizedBox(height: 5),
                  Text('👨‍🏫 Teacher: $teacherName'),
                  const SizedBox(height: 5),
                  Text('⏰ Valid for: 30 seconds'),
                  const SizedBox(height: 5),
                  Text('🕐 Generated at: ${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
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
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showQRDetails,
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
                  colors: [
                    Colors.blue.shade50,
                    Colors.white,
                  ],
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Teacher Info Card
                      _buildTeacherInfoCard(),
                      
                      const SizedBox(height: 32),
                      
                      // QR Code Title
                      const Text(
                        'Class Attendance QR Code',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Text(
                        'Ask students to scan this QR code',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // QR Code Display
                      if (qrData.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              RepaintBoundary(
                                child: QrImageView(
                                  data: qrData,
                                  size: 250,
                                  backgroundColor: Colors.white,
                                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Timer Progress Indicator
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
                            ],
                          ),
                        )
                      else
                        // Show loading indicator while QR is being generated
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Column(
                            children: [
                              SizedBox(
                                height: 250,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              SizedBox(height: 16),
                              Text('Generating QR Code...'),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 24),
                      
                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: generateQR,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Generate New QR'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A237E),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('QR Code is ready for scanning!')),
                                );
                              },
                              icon: const Icon(Icons.share),
                              label: const Text('Share'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1A237E),
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                side: BorderSide(color: Colors.blue.shade200),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Info Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'QR code refreshes every 30 seconds automatically',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
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