import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LectureScreen extends StatelessWidget {
  final String classId;
  final String className;
  final String teacherId;
  final String teacherName;

  const LectureScreen({
    super.key, 
    required this.classId,
    required this.className,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text("Lectures - $className"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db
            .collection("attendance")
            .where("classId", isEqualTo: classId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text("Error: ${snapshot.error}"),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text("Retry"),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "No lectures found",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Attendance hasn't been marked for any lecture yet",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Group attendance records by lecture
          final Map<String, Map<String, dynamic>> lecturesMap = {};
          
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final lectureId = data['lectureId'] ?? '';
            final subject = data['subject'] ?? 'Unknown Subject';
            final date = data['date'] ?? '';
            final teacherName = data['teacherName'] ?? '';
            final timeSlot = data['timeSlot'] ?? '';
            
            if (!lecturesMap.containsKey(lectureId)) {
              lecturesMap[lectureId] = {
                'lectureId': lectureId,
                'subject': subject,
                'date': date,
                'teacherName': teacherName,
                'timeSlot': timeSlot,
                'students': <Map<String, dynamic>>[],
                'studentCount': 0,
              };
            }
            
            // Add student to this lecture
            final students = lecturesMap[lectureId]!['students'] as List<Map<String, dynamic>>;
            students.add({
              'studentId': data['studentId'],
              'studentName': data['studentName'] ?? 'Unknown',
              'studentRollNo': data['studentRollNo'] ?? '',
              'status': data['status'] ?? 'present',
            });
            
            lecturesMap[lectureId]!['studentCount'] = students.length;
          }

          final lectures = lecturesMap.values.toList();

          return ListView.builder(
            itemCount: lectures.length,
            itemBuilder: (context, index) {
              final lecture = lectures[index];
              final subject = lecture['subject'];
              final date = lecture['date'];
              final teacherName = lecture['teacherName'];
              final timeSlot = lecture['timeSlot'];
              final studentCount = lecture['studentCount'];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    child: const Icon(Icons.school, color: Colors.blue), // Changed from lecture to school
                  ),
                  title: Text(
                    subject,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Date: $date"),
                      if (timeSlot.isNotEmpty) Text("Time: $timeSlot"),
                      if (teacherName.isNotEmpty) Text("Teacher: $teacherName"),
                      Text("Students: $studentCount"),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.people, color: Colors.blue),
                        onPressed: () {
                          _showStudentList(context, lecture['students']);
                        },
                        tooltip: "View Students",
                      ),
                      IconButton(
                        icon: const Icon(Icons.bar_chart, color: Colors.green),
                        onPressed: () {
                          _showAttendanceSummary(context, lecture['students']);
                        },
                        tooltip: "Attendance Summary",
                      ),
                    ],
                  ),
                  children: [
                    // Show first 5 students preview
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Text(
                              "Students Present:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          ...(lecture['students'] as List<Map<String, dynamic>>)
                              .take(5)
                              .map((student) => ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.person, size: 20),
                                    title: Text(student['studentName']),
                                    subtitle: Text("Roll No: ${student['studentRollNo']}"),
                                    trailing: const Icon(Icons.check_circle, 
                                        color: Colors.green, size: 20),
                                  )),
                          if ((lecture['students'] as List).length > 5)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextButton(
                                onPressed: () {
                                  _showStudentList(context, lecture['students']);
                                },
                                child: Text(
                                  "+ ${(lecture['students'] as List).length - 5} more students",
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showStudentList(BuildContext context, List<Map<String, dynamic>> students) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
              ),
              child: Text(
                "Students (${students.length})",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(student['studentName'][0].toUpperCase()),
                    ),
                    title: Text(student['studentName']),
                    subtitle: Text("Roll No: ${student['studentRollNo']}"),
                    trailing: const Icon(Icons.check_circle, color: Colors.green),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttendanceSummary(BuildContext context, List<Map<String, dynamic>> students) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Attendance Summary"),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 16),
              Text(
                "Total Students: ${students.length}",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "All students marked as present",
                style: TextStyle(color: Colors.green[600]),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                "Student List:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.person, size: 16),
                      title: Text(student['studentName']),
                      trailing: Text(student['studentRollNo']),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
}

// Alternative: Simple Lecture List Screen without any icons
class SimpleLectureScreen extends StatelessWidget {
  final String classId;
  final String className;

  const SimpleLectureScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text("Lectures - $className"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db
            .collection("attendance")
            .where("classId", isEqualTo: classId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Get unique lectures
          final Map<String, Map<String, dynamic>> uniqueLectures = {};
          
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final lectureId = data['lectureId'];
            
            if (!uniqueLectures.containsKey(lectureId)) {
              uniqueLectures[lectureId] = {
                'lectureId': lectureId,
                'subject': data['subject'],
                'date': data['date'],
                'teacherName': data['teacherName'],
                'timeSlot': data['timeSlot'],
                'studentCount': 0,
              };
            }
            uniqueLectures[lectureId]!['studentCount']++;
          }

          final lectures = uniqueLectures.values.toList();

          return ListView.builder(
            itemCount: lectures.length,
            itemBuilder: (context, index) {
              final lecture = lectures[index];
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(
                    lecture['subject'] ?? 'Lecture',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Date: ${lecture['date']}"),
                      Text("Teacher: ${lecture['teacherName']}"),
                      Text("Students: ${lecture['studentCount']}"),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _showLectureDetails(context, lecture);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showLectureDetails(BuildContext context, Map<String, dynamic> lecture) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lecture['subject'] ?? 'Lecture Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow("Lecture ID:", lecture['lectureId']),
            _buildDetailRow("Date:", lecture['date']),
            _buildDetailRow("Teacher:", lecture['teacherName']),
            _buildDetailRow("Time Slot:", lecture['timeSlot']),
            _buildDetailRow("Students Present:", lecture['studentCount'].toString()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}