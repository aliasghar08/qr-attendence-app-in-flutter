import 'dart:convert';
import 'dart:math';

class QRService {
  static String generateQRData() {
    final now = DateTime.now();

    final data = {
      "classId": "CS101",
      "lectureId": "Lec1",
      "timestamp": now.toIso8601String(),
      "expiry": now.add(const Duration(seconds: 30)).toIso8601String(),
      "token": _generateToken(),
    };

    return jsonEncode(data);
  }

  static String _generateToken() {
    final rand = Random();
    return List.generate(10, (_) => rand.nextInt(9)).join();
  }
}