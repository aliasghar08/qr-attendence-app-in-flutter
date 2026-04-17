import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Check if attendance already exists for this student in this lecture
  Future<bool> checkExistingAttendance({
    required String classId,
    required String lectureId,
    required String studentId,
  }) async {
    try {
      final attendanceDoc = await _firestore
          .collection('attendance')
          .doc('$classId-$lectureId-$studentId')
          .get();
      
      return attendanceDoc.exists;
    } catch (e) {
      print('Error checking existing attendance: $e');
      return false;
    }
  }

  // Mark attendance for a student with additional data
  Future<void> markAttendance({
    required String classId,
    required String lectureId,
    required String studentId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final attendanceData = {
        'classId': classId,
        'lectureId': lectureId,
        'studentId': studentId,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'present',
        'markedAt': DateTime.now().toIso8601String(),
        ...?additionalData, // Spread additional data if provided
      };
      
      await _firestore
          .collection('attendance')
          .doc('$classId-$lectureId-$studentId')
          .set(attendanceData);
          
      print('Attendance marked successfully for student: $studentId');
    } catch (e) {
      print('Error marking attendance: $e');
      rethrow;
    }
  }

  // Get attendance records for a specific student with full details
  Future<List<QueryDocumentSnapshot>> getStudentAttendance(String studentId) async {
    try {
      final querySnapshot = await _firestore
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .orderBy('timestamp', descending: true)
          .get();
      
      return querySnapshot.docs;
    } catch (e) {
      print('Error getting student attendance: $e');
      return [];
    }
  }

  // Get attendance records for a specific student with filters
  Future<List<QueryDocumentSnapshot>> getStudentAttendanceByCourse({
    required String studentId,
    required String course,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .where('course', isEqualTo: course)
          .orderBy('timestamp', descending: true)
          .get();
      
      return querySnapshot.docs;
    } catch (e) {
      print('Error getting student attendance by course: $e');
      return [];
    }
  }

  // Get attendance records for a specific class
  Future<List<QueryDocumentSnapshot>> getClassAttendance(String classId) async {
    try {
      final querySnapshot = await _firestore
          .collection('attendance')
          .where('classId', isEqualTo: classId)
          .orderBy('timestamp', descending: true)
          .get();
      
      return querySnapshot.docs;
    } catch (e) {
      print('Error getting class attendance: $e');
      return [];
    }
  }

  // Get attendance for a specific lecture
  Future<List<QueryDocumentSnapshot>> getLectureAttendance(String lectureId) async {
    try {
      final querySnapshot = await _firestore
          .collection('attendance')
          .where('lectureId', isEqualTo: lectureId)
          .get();
      
      return querySnapshot.docs;
    } catch (e) {
      print('Error getting lecture attendance: $e');
      return [];
    }
  }

  // Get attendance for a specific subject
  Future<List<QueryDocumentSnapshot>> getSubjectAttendance({
    required String studentId,
    required String subject,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .where('subject', isEqualTo: subject)
          .orderBy('timestamp', descending: true)
          .get();
      
      return querySnapshot.docs;
    } catch (e) {
      print('Error getting subject attendance: $e');
      return [];
    }
  }

  // Check if student is present for a specific lecture
  Future<bool> isStudentPresent({
    required String classId,
    required String lectureId,
    required String studentId,
  }) async {
    try {
      final attendanceDoc = await _firestore
          .collection('attendance')
          .doc('$classId-$lectureId-$studentId')
          .get();
      
      return attendanceDoc.exists && attendanceDoc['status'] == 'present';
    } catch (e) {
      print('Error checking student presence: $e');
      return false;
    }
  }

  // Get attendance count for a lecture
  Future<int> getAttendanceCount(String lectureId) async {
    try {
      final querySnapshot = await _firestore
          .collection('attendance')
          .where('lectureId', isEqualTo: lectureId)
          .get();
      
      return querySnapshot.docs.length;
    } catch (e) {
      print('Error getting attendance count: $e');
      return 0;
    }
  }

  // Get attendance percentage for a student in a course
  Future<double> getAttendancePercentage({
    required String studentId,
    required String course,
  }) async {
    try {
      // Get total lectures for this course (you would need a lectures collection)
      // For now, we'll calculate based on marked attendance
      final attendanceSnapshot = await _firestore
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .where('course', isEqualTo: course)
          .get();
      
      final totalLectures = await _getTotalLecturesForCourse(course);
      if (totalLectures == 0) return 0.0;
      
      return (attendanceSnapshot.docs.length / totalLectures) * 100;
    } catch (e) {
      print('Error getting attendance percentage: $e');
      return 0.0;
    }
  }

  // Helper method to get total lectures for a course
  Future<int> _getTotalLecturesForCourse(String course) async {
    try {
      final lecturesSnapshot = await _firestore
          .collection('lectures')
          .where('course', isEqualTo: course)
          .get();
      
      return lecturesSnapshot.docs.length;
    } catch (e) {
      print('Error getting total lectures: $e');
      return 0;
    }
  }

  // Get all students present for a specific lecture with their details
  Future<List<Map<String, dynamic>>> getLectureAttendanceWithDetails(String lectureId) async {
    try {
      final attendanceSnapshot = await _firestore
          .collection('attendance')
          .where('lectureId', isEqualTo: lectureId)
          .get();
      
      final List<Map<String, dynamic>> studentsPresent = [];
      
      for (var doc in attendanceSnapshot.docs) {
        final studentId = doc['studentId'];
        final studentDoc = await _firestore
            .collection('users')
            .doc(studentId)
            .get();
        
        if (studentDoc.exists) {
          studentsPresent.add({
            'studentId': studentId,
            'studentName': studentDoc['name'],
            'rollNo': studentDoc['rollNo'],
            'course': studentDoc['course'],
            'batch': studentDoc['batch'],
            'semester': studentDoc['semester'],
            'attendanceTime': doc['markedAt'],
            'status': doc['status'],
          });
        }
      }
      
      return studentsPresent;
    } catch (e) {
      print('Error getting lecture attendance with details: $e');
      return [];
    }
  }

  // Get attendance summary for a teacher's course
  Future<Map<String, dynamic>> getCourseAttendanceSummary({
    required String course,
    required String teacherId,
  }) async {
    try {
      // Get all students in this course
      final studentsSnapshot = await _firestore
          .collection('users')
          .where('course', isEqualTo: course)
          .where('role', isEqualTo: 'student')
          .get();
      
      // Get all lectures for this course
      final lecturesSnapshot = await _firestore
          .collection('lectures')
          .where('course', isEqualTo: course)
          .where('teacherId', isEqualTo: teacherId)
          .get();
      
      final totalStudents = studentsSnapshot.docs.length;
      final totalLectures = lecturesSnapshot.docs.length;
      
      // Get attendance records
      final attendanceSnapshot = await _firestore
          .collection('attendance')
          .where('course', isEqualTo: course)
          .get();
      
      final totalAttendanceRecords = attendanceSnapshot.docs.length;
      
      return {
        'totalStudents': totalStudents,
        'totalLectures': totalLectures,
        'totalAttendanceRecords': totalAttendanceRecords,
        'averageAttendance': totalLectures > 0 
            ? (totalAttendanceRecords / (totalStudents * totalLectures)) * 100 
            : 0.0,
      };
    } catch (e) {
      print('Error getting course attendance summary: $e');
      return {};
    }
  }

  // Update attendance status (e.g., change from present to absent)
  Future<void> updateAttendanceStatus({
    required String classId,
    required String lectureId,
    required String studentId,
    required String newStatus,
  }) async {
    try {
      await _firestore
          .collection('attendance')
          .doc('$classId-$lectureId-$studentId')
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating attendance status: $e');
      rethrow;
    }
  }

  // Delete attendance record
  Future<void> deleteAttendance({
    required String classId,
    required String lectureId,
    required String studentId,
  }) async {
    try {
      await _firestore
          .collection('attendance')
          .doc('$classId-$lectureId-$studentId')
          .delete();
    } catch (e) {
      print('Error deleting attendance: $e');
      rethrow;
    }
  }

  // Get attendance by date range
  Future<List<QueryDocumentSnapshot>> getAttendanceByDateRange({
    required String studentId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .orderBy('timestamp', descending: true)
          .get();
      
      return querySnapshot.docs;
    } catch (e) {
      print('Error getting attendance by date range: $e');
      return [];
    }
  }
}