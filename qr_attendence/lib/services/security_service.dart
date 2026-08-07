import 'dart:convert';
import 'dart:typed_data';
import 'location_service.dart';

/// Cryptographic and Attendance Security Service
/// Provides anti-screenshot protection, rolling signature validation,
/// GPS spoofing checks, replay prevention, and tamper-evident audit hashing.
class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  // Internal Salt Secret for HMAC generation (per-installation session salt)
  static const String _secretSessionSalt = 'QR_ATTEND_SECURE_TOKEN_SALT_2026';

  // Cache to track recently consumed token nonces to prevent replay attacks
  final Set<String> _consumedTokens = {};

  // Maximum allowed clock skew/drift for dynamic QR validity (in seconds)
  static const int maxDriftSeconds = 25;

  // Maximum allowed student distance from faculty (in meters)
  static const double maxAllowedDistanceMeters = 80.0;

  // Minimum required GPS accuracy in meters (accuracy worse than 50m is flagged)
  static const double maxAcceptableAccuracyMeters = 50.0;

  /// Pure Dart SHA-256 implementation for self-contained, high-performance security
  String sha256Hex(String input) {
    final bytes = utf8.encode(input);
    final digest = _Sha256().process(Uint8List.fromList(bytes));
    return digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Generate dynamic cryptographic signature for a lecture session token
  String generateTokenSignature({
    required String lectureId,
    required String subject,
    required String date,
    required int timestampMs,
    required int nonce,
  }) {
    final raw = '$lectureId:$subject:$date:$timestampMs:$nonce:$_secretSessionSalt';
    return sha256Hex(raw);
  }

  /// Verify incoming QR token payload for validity, freshness, and anti-replay
  SecurityValidationResult validateQrToken({
    required Map<String, dynamic> payload,
  }) {
    final lectureId = payload['lectureId'] as String?;
    final subject = payload['subject'] as String?;
    final date = payload['date'] as String?;
    final timestampMs = payload['timestamp'] as int?;
    final nonce = payload['nonce'] as int?;
    final signature = payload['securitySignature'] as String?;

    if (lectureId == null || subject == null || date == null || timestampMs == null || nonce == null || signature == null) {
      return SecurityValidationResult(
        isValid: false,
        errorMessage: 'Malformed or untrusted QR payload format.',
      );
    }

    // 1. Verify Cryptographic Signature
    final expectedSig = generateTokenSignature(
      lectureId: lectureId,
      subject: subject,
      date: date,
      timestampMs: timestampMs,
      nonce: nonce,
    );

    if (signature != expectedSig) {
      return SecurityValidationResult(
        isValid: false,
        errorMessage: 'Cryptographic signature mismatch. Untrusted QR origin.',
      );
    }

    // 2. Anti-Screenshot / Freshness Window Check
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final ageSeconds = ((nowMs - timestampMs) / 1000).abs();

    if (ageSeconds > maxDriftSeconds) {
      return SecurityValidationResult(
        isValid: false,
        errorMessage: 'This QR code has expired (${ageSeconds.toInt()}s old). Screenshots and shared photos are not permitted.',
      );
    }

    // 3. Anti-Replay Nonce Check (prevents re-scanning the same exact token instance)
    final tokenFingerprint = '$lectureId:$nonce:$timestampMs';
    if (_consumedTokens.contains(tokenFingerprint)) {
      return SecurityValidationResult(
        isValid: false,
        errorMessage: 'This QR token instance has already been processed.',
      );
    }

    // Register token fingerprint
    _consumedTokens.add(tokenFingerprint);
    if (_consumedTokens.length > 500) {
      _consumedTokens.clear();
    }

    return SecurityValidationResult(
      isValid: true,
      tokenAgeSeconds: ageSeconds,
    );
  }

  /// Validate GPS Proximity and Anti-Spoofing checks
  SecurityValidationResult validateLocationProximity({
    required LocationData? teacherLocation,
    required LocationData? studentLocation,
  }) {
    if (teacherLocation == null) {
      return SecurityValidationResult(
        isValid: false,
        errorMessage: 'Faculty location unavailable for geofence verification.',
      );
    }

    if (studentLocation == null) {
      return SecurityValidationResult(
        isValid: false,
        errorMessage: 'Student GPS coordinates unavailable. Please enable device location.',
      );
    }

    // Check GPS accuracy (spoofed or poor signals often have > 50m error or 0.0)
    if (studentLocation.accuracy <= 0.0 || studentLocation.accuracy > maxAcceptableAccuracyMeters) {
      return SecurityValidationResult(
        isValid: false,
        errorMessage: 'Device GPS accuracy is too low (${studentLocation.accuracy.toStringAsFixed(1)}m). Please stand in open classroom area.',
      );
    }

    final distance = LocationService().calculateDistance(
      startLatitude: teacherLocation.latitude,
      startLongitude: teacherLocation.longitude,
      endLatitude: studentLocation.latitude,
      endLongitude: studentLocation.longitude,
    );

    if (distance > maxAllowedDistanceMeters) {
      return SecurityValidationResult(
        isValid: false,
        distanceMeters: distance,
        errorMessage: 'You are ${distance.toStringAsFixed(1)}m away from the classroom (Limit: ${maxAllowedDistanceMeters.toInt()}m).',
      );
    }

    return SecurityValidationResult(
      isValid: true,
      distanceMeters: distance,
    );
  }

  /// Generate a tamper-evident audit checksum for storing alongside the attendance record
  String generateAttendanceAuditHash({
    required String studentId,
    required String lectureId,
    required String subject,
    required String date,
    required double latitude,
    required double longitude,
    required String markedAtIso,
  }) {
    final raw = '$studentId|$lectureId|$subject|$date|$latitude|$longitude|$markedAtIso|$_secretSessionSalt';
    return sha256Hex(raw);
  }
}

class SecurityValidationResult {
  final bool isValid;
  final String? errorMessage;
  final double? distanceMeters;
  final double? tokenAgeSeconds;

  const SecurityValidationResult({
    required this.isValid,
    this.errorMessage,
    this.distanceMeters,
    this.tokenAgeSeconds,
  });
}

// ---------------------------------------------------------------------------
// Standard SHA-256 Core
// ---------------------------------------------------------------------------
class _Sha256 {
  static const List<int> _k = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  Uint8List process(Uint8List message) {
    int h0 = 0x6a09e667;
    int h1 = 0xbb67ae85;
    int h2 = 0x3c6ef372;
    int h3 = 0xa54ff53a;
    int h4 = 0x510e527f;
    int h5 = 0x9b05688c;
    int h6 = 0x1f83d9ab;
    int h7 = 0x5be0cd19;

    final length = message.length;
    final bitLength = length * 8;
    final paddingLength = (length % 64 < 56) ? 56 - (length % 64) : 120 - (length % 64);
    final padded = Uint8List(length + paddingLength + 8);
    padded.setRange(0, length, message);
    padded[length] = 0x80;

    final byteData = ByteData.view(padded.buffer);
    byteData.setUint64(padded.length - 8, bitLength, Endian.big);

    final w = Uint32List(64);

    for (int chunk = 0; chunk < padded.length; chunk += 64) {
      for (int i = 0; i < 16; i++) {
        w[i] = byteData.getUint32(chunk + i * 4, Endian.big);
      }
      for (int i = 16; i < 64; i++) {
        final s0 = _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
        final s1 = _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFF;
      }

      int a = h0, b = h1, c = h2, d = h3, e = h4, f = h5, g = h6, h = h7;

      for (int i = 0; i < 64; i++) {
        final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
        final ch = (e & f) ^ (~e & g);
        final temp1 = (h + s1 + ch + _k[i] + w[i]) & 0xFFFFFFFF;
        final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = (s0 + maj) & 0xFFFFFFFF;

        h = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xFFFFFFFF;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xFFFFFFFF;
      }

      h0 = (h0 + a) & 0xFFFFFFFF;
      h1 = (h1 + b) & 0xFFFFFFFF;
      h2 = (h2 + c) & 0xFFFFFFFF;
      h3 = (h3 + d) & 0xFFFFFFFF;
      h4 = (h4 + e) & 0xFFFFFFFF;
      h5 = (h5 + f) & 0xFFFFFFFF;
      h6 = (h6 + g) & 0xFFFFFFFF;
      h7 = (h7 + h) & 0xFFFFFFFF;
    }

    final out = ByteData(32);
    out.setUint32(0, h0, Endian.big);
    out.setUint32(4, h1, Endian.big);
    out.setUint32(8, h2, Endian.big);
    out.setUint32(12, h3, Endian.big);
    out.setUint32(16, h4, Endian.big);
    out.setUint32(20, h5, Endian.big);
    out.setUint32(24, h6, Endian.big);
    out.setUint32(28, h7, Endian.big);

    return out.buffer.asUint8List();
  }

  int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF;
}
