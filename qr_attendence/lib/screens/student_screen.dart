import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';

class StudentScreen extends StatefulWidget {
  const StudentScreen({super.key});

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {

  String scannedData = "Scan a QR code";
  bool isScanned = false;

  final firestoreService = FirestoreService();

  void onDetect(BarcodeCapture capture) async {
    if (isScanned) return;

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
        isScanned = true;

        try {
          final decoded = jsonDecode(code);

          final classId = decoded['classId'];
          final lectureId = decoded['lectureId'];

          final studentId = user.uid;

          await firestoreService.markAttendance(
            classId: classId,
            lectureId: lectureId,
            studentId: studentId,
          );

          setState(() {
            scannedData = "✅ Attendance Marked!";
          });

        } catch (e) {
          setState(() {
            scannedData = "❌ ${e.toString()}";
          });
        }

        break;
      }
    }
  }

  void resetScanner() {
    setState(() {
      isScanned = false;
      scannedData = "Scan a QR code";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Student Panel")),
      body: Column(
        children: [

          Expanded(
            flex: 4,
            child: MobileScanner(
              onDetect: onDetect,
            ),
          ),

          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                Text(
                  scannedData,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),

                const SizedBox(height: 10),

                ElevatedButton(
                  onPressed: resetScanner,
                  child: const Text("Scan Again"),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}