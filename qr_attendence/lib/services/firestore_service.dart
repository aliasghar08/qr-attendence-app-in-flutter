import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> markAttendance({
    required String classId,
    required String lectureId,
    required String studentId,
  }) async {
    final docRef = _db
        .collection('attendance')
        .doc(classId)
        .collection(lectureId)
        .doc(studentId);

    final doc = await docRef.get();

    if (doc.exists) {
      throw Exception("Already marked");
    }

    await docRef.set({
      "timestamp": FieldValue.serverTimestamp(),
    });
  }
}