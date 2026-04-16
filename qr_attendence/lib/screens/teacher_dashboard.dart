import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_attendence/screens/lecture_screen.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {

  final FirebaseFirestore db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Teacher Dashboard")),
      body: StreamBuilder(
        stream: db.collection("attendance").snapshots(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final classes = snapshot.data!.docs;

          if (classes.isEmpty) {
            return const Center(child: Text("No attendance yet"));
          }

          return ListView.builder(
            itemCount: classes.length,
            itemBuilder: (context, index) {

              final classId = classes[index].id;

              return ListTile(
                title: Text("Class: $classId"),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LectureScreen(classId: classId),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}