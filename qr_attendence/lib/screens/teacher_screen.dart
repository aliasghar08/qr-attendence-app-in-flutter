import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/qr_service.dart';

class TeacherScreen extends StatefulWidget {
  const TeacherScreen({super.key});

  @override
  State<TeacherScreen> createState() => _TeacherScreenState();
}

class _TeacherScreenState extends State<TeacherScreen> {

  String qrData = "";
  Timer? timer;

  @override
  void initState() {
    super.initState();
    generateQR();

    // 🔄 Auto refresh every 30 seconds
    timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      generateQR();
    });
  }

  void generateQR() {
    setState(() {
      qrData = QRService.generateQRData();
    });
  }

  @override
  void dispose() {
    timer?.cancel(); // 🧹 prevent memory leak
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Teacher Panel")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            if (qrData.isNotEmpty)
              QrImageView(
                data: qrData,
                size: 220,
              ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: generateQR,
              child: const Text("Generate New QR"),
            ),

            const SizedBox(height: 10),

            const Text(
              "QR refreshes every 30 seconds",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}