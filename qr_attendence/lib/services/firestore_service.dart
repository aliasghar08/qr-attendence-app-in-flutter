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
      
      // Ensure student batch and course are properly extracted
      String studentBatch = additionalData?['studentBatch'] ?? '';
      String studentCourse = additionalData?['studentCourse'] ?? '';
      String studentRollNo = additionalData?['studentRollNo'] ?? '';
      String studentName = additionalData?['studentName'] ?? '';
      
      // If studentBatch is empty, try to get it from the student document
      if (studentBatch.isEmpty || studentCourse.isEmpty) {
        try {
          final studentDoc = await _firestore
              .collection('users')
              .doc(studentId)
              .get();
          
          if (studentDoc.exists) {
            studentBatch = studentDoc['batch'] ?? '';
            studentCourse = studentDoc['course'] ?? '';
            studentRollNo = studentDoc['rollNo'] ?? '';
            studentName = studentDoc['name'] ?? studentName;
          }
        } catch (e) {
          print('Error fetching student data from Firestore: $e');
        }
      }
      
      final attendanceData = {
        'attendanceId': compositeId,
        'classId': classId,
        'lectureId': lectureId,
        'studentId': studentId,
        'studentName': studentName,
        'studentRollNo': studentRollNo,
        'studentBatch': studentBatch,
        'studentCourse': studentCourse,
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
          
      print('Attendance marked successfully for student: $studentName');
      print('Student Batch: $studentBatch, Course: $studentCourse');
    } catch (e) {
      print('Error marking attendance: $e');
      rethrow;
    }
  }

  // Alternative method to mark attendance with explicit student data
  Future<void> markAttendanceWithDetails({
    required String classId,
    required String lectureId,
    required String studentId,
    required String studentName,
    required String studentRollNo,
    required String studentBatch,
    required String studentCourse,
    required String subject,
    required String date,
    String? teacherId,
    String? teacherName,
    String? timeSlot,
    String? department,
  }) async {
    try {
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
        'studentName': studentName,
        'studentRollNo': studentRollNo,
        'studentBatch': studentBatch,
        'studentCourse': studentCourse,
        'subject': subject,
        'date': date,
        'teacherId': teacherId ?? '',
        'teacherName': teacherName ?? '',
        'timeSlot': timeSlot ?? '',
        'department': department ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'present',
        'markedAt': DateTime.now().toIso8601String(),
        'datePath': datePath,
        'year': year,
        'month': month,
        'day': day,
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
      
      // Also store in student's subcollection for easy access
      await _firestore
          .collection('students')
          .doc(studentId)
          .collection('attendance')
          .doc(compositeId)
          .set(attendanceData);
          
      print('Attendance marked successfully with details:');
      print('Student: $studentName (Batch: $studentBatch, Course: $studentCourse)');
    } catch (e) {
      print('Error marking attendance with details: $e');
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
          .where('studentCourse', isEqualTo: course)
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
          .where('studentCourse', isEqualTo: course)
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
        studentsPresent.add({
          'studentId': doc['studentId'],
          'studentName': doc['studentName'] ?? 'Unknown',
          'rollNo': doc['studentRollNo'] ?? '',
          'course': doc['studentCourse'] ?? '',
          'batch': doc['studentBatch'] ?? '',
          'semester': doc['semester'] ?? '',
          'attendanceTime': doc['markedAt'],
          'status': doc['status'],
        });
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
        
        // Delete from student's subcollection
        await _firestore
            .collection('students')
            .doc(studentId)
            .collection('attendance')
            .doc(compositeId)
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

  // Fix missing batch and course for existing attendance records
  Future<void> fixMissingStudentData() async {
    try {
      // Get all attendance records
      final attendanceSnapshot = await _firestore
          .collection('attendance')
          .get();
      
      int updatedCount = 0;
      
      for (var doc in attendanceSnapshot.docs) {
        final data = doc.data();
        final studentId = data['studentId'];
        final currentBatch = data['studentBatch'];
        final currentCourse = data['studentCourse'];
        
        // Only update if batch or course is missing
        if (currentBatch == null || currentBatch == '' || 
            currentCourse == null || currentCourse == '') {
          
          // Fetch student data from users collection
          final studentDoc = await _firestore
              .collection('users')
              .doc(studentId)
              .get();
          
          if (studentDoc.exists) {
            final batch = studentDoc['batch'] ?? '';
            final course = studentDoc['course'] ?? '';
            final rollNo = studentDoc['rollNo'] ?? '';
            final name = studentDoc['name'] ?? '';
            
            // Update the attendance record
            await doc.reference.update({
              'studentBatch': batch,
              'studentCourse': course,
              'studentRollNo': rollNo,
              'studentName': name,
            });
            
            // Also update in attendance_by_date if exists
            final datePath = data['datePath'];
            final subject = data['subject'];
            if (datePath != null && subject != null) {
              try {
                await _firestore
                    .collection('attendance_by_date')
                    .doc(datePath)
                    .collection(subject)
                    .doc(studentId)
                    .update({
                  'studentBatch': batch,
                  'studentCourse': course,
                  'studentRollNo': rollNo,
                  'studentName': name,
                });
              } catch (e) {
                // Document might not exist in attendance_by_date, ignore
              }
            }
            
            updatedCount++;
            print('Updated attendance record for student: $studentId');
          }
        }
      }
      
      print('Fixed $updatedCount attendance records with missing data');
    } catch (e) {
      print('Error fixing missing student data: $e');
    }
  }
}