import 'package:cloud_firestore/cloud_firestore.dart';
import 'location_service.dart';
import 'security_service.dart';

class AttendanceRecord {
  final String id;
  final String classId;
  final String lectureId;
  final String studentId;
  final String studentName;
  final String studentRollNo;
  final String studentBatch;
  final String studentCourse;
  final String subject;
  final String date;
  final String timeSlot;
  final String teacherId;
  final String teacherName;
  final String department;
  final String status;
  final DateTime? timestamp;
  final LocationData? studentLocation;
  final double? distanceMeters;
  final bool isSecurityVerified;
  final String? securityAuditHash;

  const AttendanceRecord({
    required this.id,
    required this.classId,
    required this.lectureId,
    required this.studentId,
    required this.studentName,
    required this.studentRollNo,
    required this.studentBatch,
    required this.studentCourse,
    required this.subject,
    required this.date,
    required this.timeSlot,
    required this.teacherId,
    required this.teacherName,
    required this.department,
    required this.status,
    this.timestamp,
    this.studentLocation,
    this.distanceMeters,
    this.isSecurityVerified = true,
    this.securityAuditHash,
  });

  factory AttendanceRecord.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final locationMap = data['studentLocation'] as Map<String, dynamic>?;

    return AttendanceRecord(
      id: doc.id,
      classId: data['classId'] ?? '',
      lectureId: data['lectureId'] ?? '',
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? 'Unknown',
      studentRollNo: data['studentRollNo'] ?? 'N/A',
      studentBatch: data['studentBatch'] ?? 'N/A',
      studentCourse: data['studentCourse'] ?? 'N/A',
      subject: data['subject'] ?? 'Unknown Subject',
      date: data['date'] ?? '',
      timeSlot: data['timeSlot'] ?? '',
      teacherId: data['teacherId'] ?? '',
      teacherName: data['teacherName'] ?? '',
      department: data['department'] ?? '',
      status: data['status'] ?? 'present',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
      studentLocation: locationMap != null ? LocationData.fromMap(locationMap) : null,
      distanceMeters: (data['distanceMeters'] as num?)?.toDouble(),
      isSecurityVerified: data['isSecurityVerified'] ?? true,
      securityAuditHash: data['securityAuditHash'] as String?,
    );
  }
}

class SubjectAttendanceStats {
  final String subject;
  final int total;
  final int present;
  final int absent;

  const SubjectAttendanceStats({
    required this.subject,
    required this.total,
    required this.present,
    required this.absent,
  });

  double get percentage => total > 0 ? (present / total) * 100 : 0.0;
}

class AttendanceService {
  static final AttendanceService _instance = AttendanceService._internal();
  factory AttendanceService() => _instance;
  AttendanceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SecurityService _securityService = SecurityService();

  /// Check if a student has already attended a lecture today
  Future<bool> hasAttendedToday({
    required String studentId,
    required String subject,
    required String date,
  }) async {
    try {
      final compositeId = '${studentId}_${subject}_$date';
      final doc = await _firestore.collection('attendance').doc(compositeId).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  /// Mark attendance for a student with complete metadata, geofence, and cryptographic audit hash
  Future<void> markAttendance({
    required String lectureId,
    required String classId,
    required String studentId,
    required String studentName,
    required String studentRollNo,
    required String studentBatch,
    required String studentCourse,
    required String subject,
    required String date,
    required String timeSlot,
    required String teacherId,
    required String teacherName,
    required String department,
    LocationData? teacherLocation,
    LocationData? studentLocation,
    double? tokenAgeSeconds,
  }) async {
    final compositeId = '${studentId}_${subject}_$date';

    // Verify duplicate attendance
    final existingDoc = await _firestore.collection('attendance').doc(compositeId).get();
    if (existingDoc.exists) {
      throw Exception('Attendance already marked for $subject on $date');
    }

    double? distance;
    if (teacherLocation != null && studentLocation != null) {
      distance = LocationService().calculateDistance(
        startLatitude: teacherLocation.latitude,
        startLongitude: teacherLocation.longitude,
        endLatitude: studentLocation.latitude,
        endLongitude: studentLocation.longitude,
      );
    }

    final now = DateTime.now();
    final datePath = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final markedAtIso = now.toIso8601String();

    // Generate cryptographic audit hash
    final auditHash = _securityService.generateAttendanceAuditHash(
      studentId: studentId,
      lectureId: lectureId,
      subject: subject,
      date: date,
      latitude: studentLocation?.latitude ?? 0.0,
      longitude: studentLocation?.longitude ?? 0.0,
      markedAtIso: markedAtIso,
    );

    final attendanceData = {
      'attendanceId': compositeId,
      'lectureId': lectureId,
      'classId': classId,
      'studentId': studentId,
      'studentName': studentName,
      'studentRollNo': studentRollNo,
      'studentBatch': studentBatch,
      'studentCourse': studentCourse,
      'subject': subject,
      'date': date,
      'timeSlot': timeSlot,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'department': department,
      'status': 'present',
      'timestamp': FieldValue.serverTimestamp(),
      'markedAt': markedAtIso,
      'datePath': datePath,
      'isSecurityVerified': true,
      'securityAuditHash': auditHash,
      'studentLocation': ?studentLocation?.toMap(),
      'teacherLocation': ?teacherLocation?.toMap(),
      'distanceMeters': ?distance,
      'tokenAgeSeconds': ?tokenAgeSeconds,
      'deviceAccuracyMeters': ?studentLocation?.accuracy,
    };

    // Store in global attendance collection
    await _firestore.collection('attendance').doc(compositeId).set(attendanceData);

    // Also store in attendance_by_date for indexed partitioning
    await _firestore
        .collection('attendance_by_date')
        .doc(datePath)
        .collection(subject)
        .doc(studentId)
        .set(attendanceData);
  }

  /// Real-time stream of attendance records for a specific student
  Stream<List<AttendanceRecord>> streamStudentAttendance(String studentId) {
    return _firestore
        .collection('attendance')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
      final records = snapshot.docs.map((doc) => AttendanceRecord.fromDoc(doc)).toList();
      records.sort((a, b) {
        if (a.timestamp == null && b.timestamp == null) return 0;
        if (a.timestamp == null) return 1;
        if (b.timestamp == null) return -1;
        return b.timestamp!.compareTo(a.timestamp!);
      });
      return records;
    });
  }

  /// Calculate subject-wise attendance statistics
  Map<String, SubjectAttendanceStats> calculateSubjectStats(List<AttendanceRecord> records) {
    final Map<String, int> presentCounts = {};
    final Map<String, int> totalCounts = {};

    for (final record in records) {
      final subject = record.subject;
      totalCounts[subject] = (totalCounts[subject] ?? 0) + 1;
      if (record.status.toLowerCase() == 'present') {
        presentCounts[subject] = (presentCounts[subject] ?? 0) + 1;
      }
    }

    final Map<String, SubjectAttendanceStats> result = {};
    for (final entry in totalCounts.entries) {
      final subject = entry.key;
      final total = entry.value;
      final present = presentCounts[subject] ?? 0;
      final absent = total - present;
      result[subject] = SubjectAttendanceStats(
        subject: subject,
        total: total,
        present: present,
        absent: absent,
      );
    }
    return result;
  }

  /// Real-time stream of attendance records for a teacher
  Stream<QuerySnapshot> streamTeacherAttendance(String teacherId) {
    return _firestore
        .collection('attendance')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots();
  }
}
