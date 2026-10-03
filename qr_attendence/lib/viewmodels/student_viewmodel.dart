import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/attendance_service.dart';
import '../services/location_service.dart';
import '../services/security_service.dart';

class StudentAttendanceResult {
  final bool isSuccess;
  final String? errorMessage;
  final Map<String, dynamic>? attendanceDetails;

  StudentAttendanceResult({
    required this.isSuccess,
    this.errorMessage,
    this.attendanceDetails,
  });
}

class StudentViewModel extends ChangeNotifier {
  final LocationService? _locationService;
  final AttendanceService? _attendanceService;
  final SecurityService? _securityService;

  StudentViewModel({
    LocationService? locationService,
    AttendanceService? attendanceService,
    SecurityService? securityService,
  })  : _locationService = locationService,
        _attendanceService = attendanceService,
        _securityService = securityService;

  LocationService get locationService => _locationService ?? LocationService();
  AttendanceService get attendanceService => _attendanceService ?? AttendanceService();
  SecurityService get securityService => _securityService ?? SecurityService();

  LocationData? _currentLocation;
  LocationData? get currentLocation => _currentLocation;

  bool _isFetchingLocation = false;
  bool get isFetchingLocation => _isFetchingLocation;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  bool _isTorchOn = false;
  bool get isTorchOn => _isTorchOn;

  String? _lastErrorMessage;
  String? get lastErrorMessage => _lastErrorMessage;

  Map<String, dynamic>? _lastSuccessDetails;
  Map<String, dynamic>? get lastSuccessDetails => _lastSuccessDetails;

  Future<void> fetchLocation({bool force = false}) async {
    _isFetchingLocation = true;
    notifyListeners();

    try {
      _currentLocation = await locationService.getCurrentLocation(forceRefresh: force);
    } catch (_) {
      // Handled gracefully, will retry or use fallback
    } finally {
      _isFetchingLocation = false;
      notifyListeners();
    }
  }

  void toggleTorch(MobileScannerController controller) {
    _isTorchOn = !_isTorchOn;
    controller.toggleTorch();
    notifyListeners();
  }

  Future<StudentAttendanceResult> processBarcode({
    required BarcodeCapture capture,
    required String userId,
    required String userName,
    required Map<String, dynamic> userData,
  }) async {
    if (_isProcessing) {
      return StudentAttendanceResult(isSuccess: false, errorMessage: 'Already processing.');
    }

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) {
      return StudentAttendanceResult(isSuccess: false);
    }

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) {
      return StudentAttendanceResult(isSuccess: false);
    }

    _isProcessing = true;
    _lastErrorMessage = null;
    notifyListeners();

    try {
      final Map<String, dynamic> data = jsonDecode(rawValue);
      final lectureId = data['lectureId'] as String?;
      final classId = data['classId'] as String?;
      final subject = data['subject'] as String?;
      final date = data['date'] as String?;
      final timeSlot = data['timeSlot'] as String? ?? '';
      final teacherId = data['teacherId'] as String? ?? '';
      final teacherName = data['teacherName'] as String? ?? '';
      final department = data['department'] as String? ?? '';

      if (lectureId == null || subject == null || date == null) {
        throw Exception('Invalid QR code format. Not a valid lecture token.');
      }

      // 1. Anti-Screenshot & Cryptographic Token Signature Validation
      final tokenValidation = securityService.validateQrToken(payload: data);
      if (!tokenValidation.isValid) {
        throw Exception(tokenValidation.errorMessage ?? 'Cryptographic verification failed.');
      }

      // 2. Check duplicate attendance
      final alreadyAttended = await attendanceService.hasAttendedToday(
        studentId: userId,
        subject: subject,
        date: date,
      );

      if (alreadyAttended) {
        throw Exception('You have already marked attendance for $subject today ($date).');
      }

      // Teacher location from QR payload
      LocationData? teacherLoc;
      if (data['location'] != null) {
        teacherLoc = LocationData.fromMap(data['location']);
      }

      // Ensure fresh student location
      LocationData? studentLoc = _currentLocation;
      studentLoc ??= await locationService.getCurrentLocation(forceRefresh: true);

      // 3. Strict Geofence & Anti-Spoofing Proximity Validation
      if (teacherLoc != null && studentLoc != null) {
        final locValidation = securityService.validateLocationProximity(
          teacherLocation: teacherLoc,
          studentLocation: studentLoc,
        );

        if (!locValidation.isValid) {
          throw Exception(locValidation.errorMessage ?? 'Geofence boundary check failed.');
        }
      }

      // 4. Mark Attendance with Security Metadata & Cryptographic Audit Hash
      await attendanceService.markAttendance(
        lectureId: lectureId,
        classId: classId ?? '',
        studentId: userId,
        studentName: userName,
        studentRollNo: userData['rollNo'] ?? 'N/A',
        studentBatch: userData['batch'] ?? 'N/A',
        studentCourse: userData['course'] ?? 'N/A',
        subject: subject,
        date: date,
        timeSlot: timeSlot,
        teacherId: teacherId,
        teacherName: teacherName,
        department: department,
        teacherLocation: teacherLoc,
        studentLocation: studentLoc,
        tokenAgeSeconds: tokenValidation.tokenAgeSeconds,
      );

      final details = {
        'subject': subject,
        'teacherName': teacherName,
        'date': date,
        'timeSlot': timeSlot,
      };

      _lastSuccessDetails = details;
      return StudentAttendanceResult(
        isSuccess: true,
        attendanceDetails: details,
      );
    } catch (e) {
      final msg = e.toString().replaceAll('Exception:', '').trim();
      _lastErrorMessage = msg;
      return StudentAttendanceResult(
        isSuccess: false,
        errorMessage: msg,
      );
    } finally {
      // Cooldown pause before next scan
      await Future.delayed(const Duration(milliseconds: 1500));
      _isProcessing = false;
      notifyListeners();
    }
  }

  void resetMessages() {
    _lastErrorMessage = null;
    _lastSuccessDetails = null;
    notifyListeners();
  }
}
