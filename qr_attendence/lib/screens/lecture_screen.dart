import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_attendence/screens/attendence_screen.dart';

class LectureScreen extends StatelessWidget {
  final String classId;

  const LectureScreen({super.key, required this.classId});

  @override
  Widget build(BuildContext context) {

    final db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(title: Text("Lectures - $classId")),
      body: StreamBuilder(
        stream: db.collection("attendance").doc(classId).snapshots(),
        builder: (context, snapshot) {

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("No lectures"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          return ListView(
            children: data.keys.map((lectureId) {

              return ListTile(
                title: Text("Lecture: $lectureId"),
                trailing: const Icon(Icons.people),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AttendanceScreen(
                        classId: classId,
                        lectureId: lectureId,
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }
}