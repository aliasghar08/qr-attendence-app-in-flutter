import 'package:flutter/material.dart';
import 'teacher_screen.dart';
import 'student_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("QR Attendance System")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TeacherScreen(),
                  ),
                );
              },
              child: const Text("Teacher"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StudentScreen(),
                  ),
                );
              },
              child: const Text("Student"),
            ),
          ],
        ),
      ),
    );
  }
}