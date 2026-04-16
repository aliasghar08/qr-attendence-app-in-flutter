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

  // Mark attendance for a student
  Future<void> markAttendance({
    required String classId,
    required String lectureId,
    required String studentId,
  }) async {
    try {
      await _firestore
          .collection('attendance')
          .doc('$classId-$lectureId-$studentId')
          .set({
        'classId': classId,
        'lectureId': lectureId,
        'studentId': studentId,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'present',
        'markedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error marking attendance: $e');
      rethrow;
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
}