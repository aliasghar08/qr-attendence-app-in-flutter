import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_attendence/services/location_service.dart';
import 'package:qr_attendence/services/security_service.dart';
import 'package:qr_attendence/widgets/clock_time_picker.dart';
import 'package:qr_attendence/widgets/custom_components.dart';

void main() {
  testWidgets('ClockTimePickerCard widget smoke test', (WidgetTester tester) async {
    String changedSlot = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClockTimePickerCard(
            initialStartTime: const TimeOfDay(hour: 9, minute: 30),
            initialDurationMinutes: 45,
            onTimeSlotChanged: (slot) {
              changedSlot = slot;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Lecture Time & Duration'), findsOneWidget);
    expect(find.text('45 mins'), findsWidgets);
    expect(changedSlot, contains('45 mins'));
  });

  testWidgets('Custom PlannerCard smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlannerCard(
            child: Text('Test Card Content'),
          ),
        ),
      ),
    );

    expect(find.text('Test Card Content'), findsOneWidget);
  });

  test('SecurityService cryptographic hashing and token validation test', () {
    final sec = SecurityService();
    final hash1 = sec.sha256Hex('test_string_123');
    final hash2 = sec.sha256Hex('test_string_123');
    final hash3 = sec.sha256Hex('different_string');

    expect(hash1, equals(hash2));
    expect(hash1, isNot(equals(hash3)));
    expect(hash1.length, equals(64));

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final sig = sec.generateTokenSignature(
      lectureId: 'LEC_123',
      subject: 'Data Structures',
      date: '2026-08-07',
      timestampMs: nowMs,
      nonce: 1,
    );

    // Valid Token
    final validResult = sec.validateQrToken(payload: {
      'lectureId': 'LEC_123',
      'subject': 'Data Structures',
      'date': '2026-08-07',
      'timestamp': nowMs,
      'nonce': 1,
      'securitySignature': sig,
    });
    expect(validResult.isValid, isTrue);

    // Tampered Token Rejection
    final tamperedResult = sec.validateQrToken(payload: {
      'lectureId': 'LEC_123',
      'subject': 'Data Structures (Hacked)',
      'date': '2026-08-07',
      'timestamp': nowMs,
      'nonce': 1,
      'securitySignature': sig,
    });
    expect(tamperedResult.isValid, isFalse);

    // Expired / Screenshot Token Rejection (e.g. 60 seconds old)
    final expiredMs = nowMs - 60000;
    final expiredSig = sec.generateTokenSignature(
      lectureId: 'LEC_OLD',
      subject: 'Algorithms',
      date: '2026-08-07',
      timestampMs: expiredMs,
      nonce: 2,
    );
    final expiredResult = sec.validateQrToken(payload: {
      'lectureId': 'LEC_OLD',
      'subject': 'Algorithms',
      'date': '2026-08-07',
      'timestamp': expiredMs,
      'nonce': 2,
      'securitySignature': expiredSig,
    });
    expect(expiredResult.isValid, isFalse);
    expect(expiredResult.errorMessage, contains('expired'));
  });

  test('SecurityService Geofence proximity test', () {
    final sec = SecurityService();

    final teacherLoc = LocationData(
      latitude: 31.5204,
      longitude: 74.3587,
      address: 'Department of Computer Science',
      accuracy: 5.0,
      timestamp: DateTime.now(),
    );

    // Student close to teacher (within 10m)
    final studentCloseLoc = LocationData(
      latitude: 31.52045,
      longitude: 74.35875,
      address: 'Department of Computer Science',
      accuracy: 5.0,
      timestamp: DateTime.now(),
    );

    final closeResult = sec.validateLocationProximity(
      teacherLocation: teacherLoc,
      studentLocation: studentCloseLoc,
    );
    expect(closeResult.isValid, isTrue);

    // Student far away (> 200m away)
    final studentFarLoc = LocationData(
      latitude: 31.5250,
      longitude: 74.3650,
      address: 'Hostel Block B',
      accuracy: 5.0,
      timestamp: DateTime.now(),
    );

    final farResult = sec.validateLocationProximity(
      teacherLocation: teacherLoc,
      studentLocation: studentFarLoc,
    );
    expect(farResult.isValid, isFalse);
    expect(farResult.errorMessage, contains('away from the classroom'));
  });
}
