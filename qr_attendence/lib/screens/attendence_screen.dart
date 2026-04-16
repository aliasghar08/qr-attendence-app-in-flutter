import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AttendanceScreen extends StatelessWidget {

  final String classId;
  final String lectureId;

  const AttendanceScreen({
    super.key,
    required this.classId,
    required this.lectureId,
  });

  @override
  Widget build(BuildContext context) {

    final db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(title: Text("Attendance - $lectureId")),
      body: StreamBuilder(
        stream: db
            .collection("attendance")
            .doc(classId)
            .collection(lectureId)
            .snapshots(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final students = snapshot.data!.docs;

          if (students.isEmpty) {
            return const Center(child: Text("No students yet"));
          }

          return ListView.builder(
            itemCount: students.length,
            itemBuilder: (context, index) {

              final studentId = students[index].id;

              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(studentId),
                subtitle: Text("Present"),
              );
            },
          );
        },
      ),
    );
  }
}