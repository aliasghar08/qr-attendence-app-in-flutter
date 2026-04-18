import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StudentAttendanceScreen extends StatelessWidget {
  final String studentId;
  final String studentName;
  final String studentBatch;
  final String studentCourse;

  const StudentAttendanceScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.studentBatch,
    required this.studentCourse,
  });

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Attendance Records"),
            Text(
              "$studentName ($studentId)",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Use the document ID range query - NO INDEX NEEDED!
        stream: db
            .collection("attendance")
            .where(FieldPath.documentId, isGreaterThanOrEqualTo: studentId)
            .where(FieldPath.documentId, isLessThanOrEqualTo: '$studentId\uf8ff')
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

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Sort manually
          final attendanceRecords = snapshot.data!.docs.toList();
          attendanceRecords.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTimestamp = aData['timestamp'] as Timestamp?;
            final bTimestamp = bData['timestamp'] as Timestamp?;
            
            if (aTimestamp == null && bTimestamp == null) return 0;
            if (aTimestamp == null) return 1;
            if (bTimestamp == null) return -1;
            
            return bTimestamp.toDate().compareTo(aTimestamp.toDate());
          });

          if (attendanceRecords.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    "No attendance records found",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Student: $studentName",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Calculate statistics
          final Map<String, Map<String, dynamic>> subjectStats = {};
          for (var doc in attendanceRecords) {
            final data = doc.data() as Map<String, dynamic>;
            final subject = data['subject'] ?? 'Unknown Subject';
            final status = data['status'] ?? 'absent';
            
            if (!subjectStats.containsKey(subject)) {
              subjectStats[subject] = {
                'total': 0,
                'present': 0,
                'absent': 0,
              };
            }
            
            subjectStats[subject]!['total'] = subjectStats[subject]!['total'] + 1;
            if (status == 'present') {
              subjectStats[subject]!['present'] = subjectStats[subject]!['present'] + 1;
            } else {
              subjectStats[subject]!['absent'] = subjectStats[subject]!['absent'] + 1;
            }
          }

          return Column(
            children: [
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Attendance Summary",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: subjectStats.entries.map((entry) {
                          final subject = entry.key;
                          final stats = entry.value;
                          final percentage = stats['total'] > 0 
                              ? (stats['present'] / stats['total']) * 100 
                              : 0;
                          final color = percentage >= 75 
                              ? Colors.green 
                              : (percentage >= 50 ? Colors.orange : Colors.red);
                          
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: color.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subject,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${stats['present']}/${stats['total']} (${percentage.toStringAsFixed(1)}%)",
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              
              Expanded(
                child: ListView.builder(
                  itemCount: attendanceRecords.length,
                  itemBuilder: (context, index) {
                    final data = attendanceRecords[index].data() as Map<String, dynamic>;
                    
                    final subject = data['subject'] ?? 'Unknown Subject';
                    final status = data['status'] ?? 'absent';
                    final timestamp = data['timestamp'] as Timestamp?;
                    final date = timestamp != null ? timestamp.toDate() : DateTime.now();
                    final teacherName = data['teacherName'] ?? '';
                    final timeSlot = data['timeSlot'] ?? '';
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: status == 'present' ? Colors.green : Colors.red,
                          child: Icon(
                            status == 'present' ? Icons.check : Icons.close,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(subject, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (teacherName.isNotEmpty) Text("Teacher: $teacherName"),
                            if (timeSlot.isNotEmpty) Text("Time: $timeSlot"),
                            const SizedBox(height: 4),
                            Text(_formatDate(date), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: status == 'present' ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: status == 'present' ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        onTap: () {
                          _showAttendanceDetails(context, data, date);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  String _formatTime(DateTime date) {
    return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  void _showAttendanceDetails(BuildContext context, Map<String, dynamic> data, DateTime date) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Attendance Details"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow("Student Name:", data['studentName'] ?? 'N/A'),
              _buildDetailRow("Roll No:", data['studentRollNo'] ?? 'N/A'),
              _buildDetailRow("Batch:", data['studentBatch'] ?? 'N/A'),
              _buildDetailRow("Course:", data['studentCourse'] ?? 'N/A'),
              const Divider(),
              _buildDetailRow("Subject:", data['subject'] ?? 'N/A'),
              _buildDetailRow("Class ID:", data['classId'] ?? 'N/A'),
              _buildDetailRow("Lecture ID:", data['lectureId'] ?? 'N/A'),
              if (data['teacherName'] != null && data['teacherName'].toString().isNotEmpty)
                _buildDetailRow("Teacher:", data['teacherName']),
              if (data['timeSlot'] != null && data['timeSlot'].toString().isNotEmpty)
                _buildDetailRow("Time Slot:", data['timeSlot']),
              const Divider(),
              _buildDetailRow("Status:", data['status'] ?? 'absent'),
              _buildDetailRow("Date:", _formatDate(date)),
              _buildDetailRow("Time:", _formatTime(date)),
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
            width: 100,
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