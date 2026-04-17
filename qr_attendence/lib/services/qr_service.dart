import 'dart:convert';
import 'dart:math';

class QRService {
  static String generateQRData({
    String? teacherId,
    String? teacherName,
    String? className,
    String? lectureTitle,
  }) {
    try {
      final now = DateTime.now();
      
      final data = {
        "classId": className?.replaceAll(' ', '_').toLowerCase() ?? "CS101",
        "lectureId": "Lec_${now.millisecondsSinceEpoch}",
        "teacherId": teacherId ?? "unknown",
        "teacherName": teacherName ?? "Teacher",
        "className": className ?? "General Class",
        "lectureTitle": lectureTitle ?? "Lecture ${now.hour}:${now.minute}",
        "timestamp": now.toIso8601String(),
        "expiry": now.add(const Duration(seconds: 30)).toIso8601String(),
        "token": _generateToken(),
      };

      return jsonEncode(data);
    } catch (e) {
      // Always return a valid JSON string even if error occurs
      return '{"classId":"CS101","lectureId":"Lec1","timestamp":"${DateTime.now().toIso8601String()}"}';
    }
  }

  static String _generateToken() {
    final rand = Random();
    return List.generate(10, (_) => rand.nextInt(9)).join();
  }
}