import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Check if student has already marked attendance for this subject today
  Future<bool> hasStudentAttendedToday({
    required String studentId,
    required String subject,
    required String date,
  }) async {
    try {
      // Create composite ID based on student, subject, and date
      final compositeId = '${studentId}_${subject}_${date}';
      
      final attendanceDoc = await _firestore
          .collection('attendance')
          .doc(compositeId)
          .get();
      
      return attendanceDoc.exists;
    } catch (e) {
      print('Error checking today\'s attendance: $e');
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
      final subject = additionalData?['subject'] ?? '';
      final date = additionalData?['date'] ?? '';
      
      // Create composite ID based on student, subject, and date to prevent duplicates
      final compositeId = '${studentId}_${subject}_${date}';
      
      final now = DateTime.now();
      final year = now.year.toString();
      final month = now.month.toString().padLeft(2, '0');
      final day = now.day.toString().padLeft(2, '0');
      final datePath = '$year-$month-$day';
      
      // First check if attendance already exists
      final existingDoc = await _firestore
          .collection('attendance')
          .doc(compositeId)
          .get();
      
      if (existingDoc.exists) {
        throw Exception('Attendance already marked for this subject today');
      }
      
      final attendanceData = {
        'attendanceId': compositeId,
        'classId': classId,
        'lectureId': lectureId,
        'studentId': studentId,
        'subject': subject,
        'date': date,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'present',
        'markedAt': DateTime.now().toIso8601String(),
        'datePath': datePath,
        'year': year,
        'month': month,
        'day': day,
        ...?additionalData,
      };
      
      // Store in main collection with composite ID
      await _firestore
          .collection('attendance')
          .doc(compositeId)
          .set(attendanceData);
      
      // Also store by date for organized queries
      await _firestore
          .collection('attendance_by_date')
          .doc(datePath)
          .collection(subject)
          .doc(studentId)
          .set(attendanceData);
          
      print('Attendance marked successfully for student: $studentId in subject: $subject');
    } catch (e) {
      print('Error marking attendance: $e');
      rethrow;
    }
  }

  // Check if attendance already exists (legacy method - kept for compatibility)
  Future<bool> checkExistingAttendance({
    required String classId,
    required String lectureId,
    required String studentId,
  }) async {
    try {
      final attendanceId = '${lectureId}_${studentId}';
      
      final attendanceDoc = await _firestore
          .collection('attendance')
          .doc(attendanceId)
          .get();
      
      return attendanceDoc.exists;
    } catch (e) {
      print('Error checking existing attendance: $e');
      return false;
    }
  }

  // Get attendance records for a specific student
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

  // Get attendance records for a specific student and lecture (legacy)
  Future<bool> hasStudentAttendedLecture({
    required String studentId,
    required String lectureId,
  }) async {
    try {
      final attendanceId = '${lectureId}_${studentId}';
      final doc = await _firestore
          .collection('attendance')
          .doc(attendanceId)
          .get();
      
      return doc.exists;
    } catch (e) {
      print('Error checking lecture attendance: $e');
      return false;
    }
  }

  // Get attendance records for a specific student in a course
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

  // Get attendance for a specific lecture (all students)
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

  // Get attendance for a specific lecture by date
  Future<List<QueryDocumentSnapshot>> getLectureAttendanceByDate({
    required String lectureId,
    required DateTime date,
  }) async {
    try {
      final year = date.year.toString();
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      final datePath = '$year-$month-$day';
      
      final querySnapshot = await _firestore
          .collection('attendance_by_date')
          .doc(datePath)
          .collection(lectureId)
          .get();
      
      return querySnapshot.docs;
    } catch (e) {
      print('Error getting lecture attendance by date: $e');
      return [];
    }
  }

  // Get attendance for a specific student on a specific date
  Future<List<QueryDocumentSnapshot>> getStudentAttendanceByDate({
    required String studentId,
    required DateTime date,
  }) async {
    try {
      final year = date.year.toString();
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      final datePath = '$year-$month-$day';
      
      final querySnapshot = await _firestore
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .where('date', isEqualTo: datePath)
          .get();
      
      return querySnapshot.docs;
    } catch (e) {
      print('Error getting student attendance by date: $e');
      return [];
    }
  }

  // Get attendance summary for a student in a course
  Future<Map<String, dynamic>> getStudentAttendanceSummary({
    required String studentId,
    required String course,
  }) async {
    try {
      final attendanceSnapshot = await _firestore
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .where('course', isEqualTo: course)
          .get();
      
      final totalPresent = attendanceSnapshot.docs.length;
      
      return {
        'totalPresent': totalPresent,
        'status': totalPresent > 0 ? 'Present' : 'No Records',
      };
    } catch (e) {
      print('Error getting attendance summary: $e');
      return {
        'totalPresent': 0,
        'status': 'No Data',
      };
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

  // Delete attendance record (for corrections)
  Future<void> deleteAttendance({
    required String studentId,
    required String subject,
    required String date,
  }) async {
    try {
      final compositeId = '${studentId}_${subject}_${date}';
      
      // Get the attendance record first to know the date
      final attendanceDoc = await _firestore
          .collection('attendance')
          .doc(compositeId)
          .get();
      
      if (attendanceDoc.exists) {
        final datePath = attendanceDoc['datePath'];
        
        // Delete from date-organized collection
        await _firestore
            .collection('attendance_by_date')
            .doc(datePath)
            .collection(subject)
            .doc(studentId)
            .delete();
      }
      
      // Delete from main collection
      await _firestore
          .collection('attendance')
          .doc(compositeId)
          .delete();
      
      print('Attendance deleted for student: $studentId, subject: $subject, date: $date');
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

  // Get all attendance records for a specific date
  Future<List<QueryDocumentSnapshot>> getAttendanceByDate(DateTime date) async {
    try {
      final year = date.year.toString();
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      final datePath = '$year-$month-$day';
      
      final querySnapshot = await _firestore
          .collection('attendance')
          .where('date', isEqualTo: datePath)
          .get();
      
      return querySnapshot.docs;
    } catch (e) {
      print('Error getting attendance by date: $e');
      return [];
    }
  }

  // Get all lectures taught by a teacher
  Future<List<QueryDocumentSnapshot>> getTeacherLectures(String teacherId) async {
    try {
      final querySnapshot = await _firestore
          .collection('attendance')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      
      return querySnapshot.docs;
    } catch (e) {
      print('Error getting teacher lectures: $e');
      return [];
    }
  }
}