import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TeacherLectureHistoryScreen extends StatelessWidget {
  final String teacherId;
  final String teacherName;

  const TeacherLectureHistoryScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text("Lecture History - $teacherName"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {},
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db
            .collection("attendance")
            .where("teacherId", isEqualTo: teacherId)
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history_edu, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    "No lectures taken yet",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Teacher: $teacherName",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Lectures appear here when at least one student marks attendance",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Group by lecture (unique lectureId)
          final Map<String, Map<String, dynamic>> lecturesMap = {};
          
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final lectureId = data['lectureId'] ?? '';
            final subject = data['subject'] ?? 'Unknown Subject';
            final date = data['date'] ?? '';
            final classId = data['classId'] ?? '';
            final className = data['className'] ?? '';
            final timeSlot = data['timeSlot'] ?? '';
            final department = data['department'] ?? '';
            final timestamp = data['timestamp'] as Timestamp?;
            
            if (!lecturesMap.containsKey(lectureId)) {
              lecturesMap[lectureId] = {
                'lectureId': lectureId,
                'subject': subject,
                'date': date,
                'classId': classId,
                'className': className,
                'timeSlot': timeSlot,
                'department': department,
                'timestamp': timestamp,
                'students': <Map<String, dynamic>>[],
                'studentCount': 0,
              };
            }
            
            // Add student to this lecture (only if not already counted)
            final students = lecturesMap[lectureId]!['students'] as List<Map<String, dynamic>>;
            final existingStudentIds = students.map((s) => s['studentId']).toList();
            
            if (!existingStudentIds.contains(data['studentId'])) {
              students.add({
                'studentId': data['studentId'],
                'studentName': data['studentName'] ?? 'Unknown',
                'studentRollNo': data['studentRollNo'] ?? '',
                'studentBatch': data['studentBatch'] ?? '',
                'studentCourse': data['studentCourse'] ?? '',
              });
            }
            
            lecturesMap[lectureId]!['studentCount'] = students.length;
          }

          final lectures = lecturesMap.values.toList();
          
          // Sort by date (newest first)
          lectures.sort((a, b) {
            final aDate = a['date'] ?? '';
            final bDate = b['date'] ?? '';
            return bDate.compareTo(aDate);
          });

          // Calculate statistics
          final totalLectures = lectures.length;
          final totalStudents = lectures.fold<int>(0, (sum, lecture) => sum + (lecture['studentCount'] as int));
          final averageAttendance = totalLectures > 0 ? (totalStudents / totalLectures).toStringAsFixed(1) : '0';

          return Column(
            children: [
              // Statistics Card
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        "Teaching Statistics",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            icon: Icons.class_,
                            label: "Total Lectures",
                            value: totalLectures.toString(),
                            color: Colors.blue,
                          ),
                          _buildStatItem(
                            icon: Icons.people,
                            label: "Total Students",
                            value: totalStudents.toString(),
                            color: Colors.green,
                          ),
                          _buildStatItem(
                            icon: Icons.trending_up,
                            label: "Avg per Lecture",
                            value: averageAttendance,
                            color: Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Lectures List
              Expanded(
                child: ListView.builder(
                  itemCount: lectures.length,
                  itemBuilder: (context, index) {
                    final lecture = lectures[index];
                    return _buildLectureCard(context, lecture);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildLectureCard(BuildContext context, Map<String, dynamic> lecture) {
    final lectureId = lecture['lectureId'];
    final subject = lecture['subject'];
    final date = lecture['date'];
    final className = lecture['className'];
    final timeSlot = lecture['timeSlot'];
    final studentCount = lecture['studentCount'];
    final students = lecture['students'] as List<Map<String, dynamic>>;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withOpacity(0.1),
          child: const Icon(Icons.class_outlined, color: Colors.blue),
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
            if (className.isNotEmpty) Text("Class: $className"),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "$studentCount student${studentCount != 1 ? 's' : ''} attended",
                style: const TextStyle(fontSize: 12, color: Colors.green),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.people, color: Colors.blue),
              onPressed: () {
                _showStudentList(context, students, subject, date);
              },
              tooltip: "View Students",
            ),
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.grey),
              onPressed: () {
                _showLectureDetails(context, lecture);
              },
              tooltip: "Lecture Details",
            ),
          ],
        ),
        children: [
          // Students list
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    "Students Who Attended:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        child: Text(
                          student['studentName'][0].toUpperCase(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      title: Text(student['studentName']),
                      subtitle: Text("Roll No: ${student['studentRollNo']} | Batch: ${student['studentBatch']}"),
                      trailing: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showStudentList(BuildContext context, List<Map<String, dynamic>> students, String subject, String date) {
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
              child: Column(
                children: [
                  Text(
                    subject,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Date: $date",
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${students.length} Student${students.length != 1 ? 's' : ''} Attended",
                      style: const TextStyle(color: Colors.green),
                    ),
                  ),
                ],
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
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Roll No: ${student['studentRollNo']}"),
                        Text("Batch: ${student['studentBatch']} | Course: ${student['studentCourse']}"),
                      ],
                    ),
                    trailing: const Icon(Icons.check_circle, color: Colors.green),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLectureDetails(BuildContext context, Map<String, dynamic> lecture) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lecture['subject'] ?? 'Lecture Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow("Lecture ID:", lecture['lectureId']),
              _buildDetailRow("Subject:", lecture['subject']),
              _buildDetailRow("Date:", lecture['date']),
              if (lecture['timeSlot'] != null && lecture['timeSlot'].toString().isNotEmpty)
                _buildDetailRow("Time Slot:", lecture['timeSlot']),
              if (lecture['className'] != null && lecture['className'].toString().isNotEmpty)
                _buildDetailRow("Class:", lecture['className']),
              if (lecture['classId'] != null && lecture['classId'].toString().isNotEmpty)
                _buildDetailRow("Class ID:", lecture['classId']),
              if (lecture['department'] != null && lecture['department'].toString().isNotEmpty)
                _buildDetailRow("Department:", lecture['department']),
              const Divider(),
              _buildDetailRow("Students Attended:", lecture['studentCount'].toString()),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

// Alternative: Simple Version without ExpansionTile
class SimpleTeacherLectureHistoryScreen extends StatelessWidget {
  final String teacherId;
  final String teacherName;

  const SimpleTeacherLectureHistoryScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text("Lectures - $teacherName"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db
            .collection("attendance")
            .where("teacherId", isEqualTo: teacherId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Group by lecture
          final Map<String, Map<String, dynamic>> lecturesMap = {};
          
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final lectureId = data['lectureId'] ?? '';
            
            if (!lecturesMap.containsKey(lectureId)) {
              lecturesMap[lectureId] = {
                'lectureId': lectureId,
                'subject': data['subject'] ?? 'Unknown',
                'date': data['date'] ?? '',
                'timeSlot': data['timeSlot'] ?? '',
                'className': data['className'] ?? '',
                'studentCount': 0,
                'students': <String>[],
              };
            }
            
            final students = lecturesMap[lectureId]!['students'] as List<String>;
            if (!students.contains(data['studentId'])) {
              students.add(data['studentId']);
              lecturesMap[lectureId]!['studentCount'] = students.length;
            }
          }

          final lectures = lecturesMap.values.toList();
          lectures.sort((a, b) => b['date'].compareTo(a['date']));

          return ListView.builder(
            itemCount: lectures.length,
            itemBuilder: (context, index) {
              final lecture = lectures[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.class_, color: Colors.blue),
                  title: Text(
                    lecture['subject'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Date: ${lecture['date']}"),
                      if (lecture['timeSlot'].isNotEmpty) 
                        Text("Time: ${lecture['timeSlot']}"),
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
        title: Text(lecture['subject']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow("Date:", lecture['date']),
            _buildDetailRow("Time:", lecture['timeSlot']),
            _buildDetailRow("Class:", lecture['className']),
            _buildDetailRow("Students:", lecture['studentCount'].toString()),
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
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

// Usage example - how to navigate to this screen
class TeacherDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Teacher Dashboard")),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TeacherLectureHistoryScreen(
                  teacherId: "current_teacher_id", // Replace with actual teacher ID
                  teacherName: "John Doe", // Replace with actual teacher name
                ),
              ),
            );
          },
          child: const Text("View Lecture History"),
        ),
      ),
    );
  }
}