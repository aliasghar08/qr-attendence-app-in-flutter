import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Check if student has already marked attendance for this subject today
  Future<bool> hasStudentAttendedToday({
    required String studentId,
    required String subject,
    required String date,
  }) async {
    try {
      final compositeId = '${studentId}_${subject}_$date';
      final attendanceDoc = await _firestore
          .collection('attendance')
          .doc(compositeId)
          .get();
      return attendanceDoc.exists;
    } catch (_) {
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
      final compositeId = '${studentId}_${subject}_$date';

      final now = DateTime.now();
      final year = now.year.toString();
      final month = now.month.toString().padLeft(2, '0');
      final day = now.day.toString().padLeft(2, '0');
      final datePath = '$year-$month-$day';

      final existingDoc = await _firestore
          .collection('attendance')
          .doc(compositeId)
          .get();

      if (existingDoc.exists) {
        throw Exception('Attendance already marked for this subject today');
      }

      String studentBatch = '';
      String studentCourse = '';
      String studentRollNo = '';
      String studentName = '';

      try {
        final studentDoc = await _firestore
            .collection('users')
            .doc(studentId)
            .get();

        if (studentDoc.exists) {
          final data = studentDoc.data() ?? {};
          studentBatch = data['batch'] ?? '';
          studentCourse = data['course'] ?? '';
          studentRollNo = data['rollNo'] ?? '';
          studentName = data['name'] ?? '';
        }
      } catch (_) {}

      if (studentBatch.isEmpty) {
        studentBatch = additionalData?['studentBatch'] ?? '';
      }
      if (studentCourse.isEmpty) {
        studentCourse = additionalData?['studentCourse'] ?? '';
      }
      if (studentRollNo.isEmpty) {
        studentRollNo = additionalData?['studentRollNo'] ?? '';
      }
      if (studentName.isEmpty) {
        studentName = additionalData?['studentName'] ?? '';
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

      await _firestore
          .collection('attendance')
          .doc(compositeId)
          .set(attendanceData);

      await _firestore
          .collection('attendance_by_date')
          .doc(datePath)
          .collection(subject)
          .doc(studentId)
          .set(attendanceData);
    } catch (_) {
      rethrow;
    }
  }

  // Mark attendance with explicit student details
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
    final compositeId = '${studentId}_${subject}_$date';

    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final datePath = '$year-$month-$day';

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

    await _firestore
        .collection('attendance')
        .doc(compositeId)
        .set(attendanceData);

    await _firestore
        .collection('attendance_by_date')
        .doc(datePath)
        .collection(subject)
        .doc(studentId)
        .set(attendanceData);

    await _firestore
        .collection('students')
        .doc(studentId)
        .collection('attendance')
        .doc(compositeId)
        .set(attendanceData);
  }

  // Get attendance records for a specific student
  Future<List<QueryDocumentSnapshot>> getStudentAttendance(
    String studentId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .get();
      return snapshot.docs;
    } catch (_) {
      return [];
    }
  }

  // Check if attendance already exists
  Future<bool> checkExistingAttendance({
    required String classId,
    required String lectureId,
    required String studentId,
  }) async {
    try {
      final attendanceId = '${lectureId}_$studentId';
      final doc = await _firestore.collection('attendance').doc(attendanceId).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }
}
