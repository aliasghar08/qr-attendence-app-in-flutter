import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

class StudentScreen extends StatefulWidget {
  const StudentScreen({super.key});

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> with SingleTickerProviderStateMixin {
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
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (doc.exists) {
          setState(() {
            studentName = doc['name'] ?? 'Student';
            studentRollNo = doc['rollNo'] ?? '';
            isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          isLoading = false;
        });
      }
    } else {
      setState(() {
        isLoading = false;
      });
    }
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

          final classId = decoded['classId'];
          final lectureId = decoded['lectureId'];
          final className = decoded['className'] ?? 'Class';
          final lectureTitle = decoded['lectureTitle'] ?? 'Lecture';
          final timestamp = decoded['timestamp'];

          // Check if QR code is expired (e.g., valid for 15 minutes)
          if (timestamp != null) {
            final qrTime = DateTime.parse(timestamp);
            final now = DateTime.now();
            final difference = now.difference(qrTime);
            
            if (difference.inMinutes > 15) {
              setState(() {
                scannedData = "❌ QR Code Expired!\nPlease scan a valid QR code.";
                isProcessing = false;
              });
              
              // Auto reset after 3 seconds
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) resetScanner();
              });
              return;
            }
          }

          final studentId = user.uid;

          // Check if already marked attendance for this lecture
          final existingAttendance = await firestoreService.checkExistingAttendance(
            classId: classId,
            lectureId: lectureId,
            studentId: studentId,
          );

          if (existingAttendance) {
            setState(() {
              scannedData = "⚠️ Attendance already marked for this lecture!";
              isProcessing = false;
            });
            
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) resetScanner();
            });
            return;
          }

          // Mark attendance
          await firestoreService.markAttendance(
            classId: classId,
            lectureId: lectureId,
            studentId: studentId,
          );

          setState(() {
            scannedData = "✅ Attendance Marked Successfully!\n📚 $className\n📖 $lectureTitle";
            isScanned = true;
            isProcessing = false;
          });

          // Show success dialog
          _showSuccessDialog(className, lectureTitle);

        } catch (e) {
          setState(() {
            scannedData = "❌ Error: ${e.toString().split(':').last}";
            isProcessing = false;
          });
          
          // Auto reset after 3 seconds on error
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

  void _showSuccessDialog(String className, String lectureTitle) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 32),
            const SizedBox(width: 10),
            const Text('Success!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attendance marked for:'),
            const SizedBox(height: 8),
            Text('📚 $className', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('📖 $lectureTitle', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 5),
            Text('Student: $studentName'),
            if (studentRollNo.isNotEmpty) Text('Roll No: $studentRollNo'),
            const SizedBox(height: 10),
            Text('Time: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}'),
          ],
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
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              resetScanner();
              setState(() {
                cameraController.start();
              });
            },
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
      body: Column(
        children: [
          // Student Info Card
          Container(
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
                        isLoading ? "Loading..." : studentName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
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
                    'Student',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          
          // Scanner Section Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.qr_code_scanner, color: const Color(0xFF1A237E)),
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
                    // Scanner overlay guide
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
                                      top: BorderSide(color: Colors.white, width: 3),
                                      left: BorderSide(color: Colors.white, width: 3),
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
                                      top: BorderSide(color: Colors.white, width: 3),
                                      right: BorderSide(color: Colors.white, width: 3),
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
                                      bottom: BorderSide(color: Colors.white, width: 3),
                                      left: BorderSide(color: Colors.white, width: 3),
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
                                      bottom: BorderSide(color: Colors.white, width: 3),
                                      right: BorderSide(color: Colors.white, width: 3),
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
            child: Container(
              margin: const EdgeInsets.all(16),
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
                            : scannedData.contains('❌') || scannedData.contains('⚠️')
                                ? Icons.error_outline
                                : Icons.qr_code_scanner,
                        size: 50,
                        color: scannedData.contains('✅')
                            ? Colors.green
                            : scannedData.contains('❌') || scannedData.contains('⚠️')
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
                          : scannedData.contains('❌') || scannedData.contains('⚠️')
                              ? Colors.red.shade700
                              : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (isScanned || scannedData.contains('❌') || scannedData.contains('⚠️'))
                    ElevatedButton.icon(
                      onPressed: resetScanner,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Scan Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                ],
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