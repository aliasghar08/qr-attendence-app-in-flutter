import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/academic_service.dart';
import '../services/location_service.dart';

class TeacherViewModel extends ChangeNotifier {
  final AcademicService _academicService;
  final LocationService? _locationService;
  final FirebaseFirestore? _firestore;

  StreamSubscription? _attendeeSubscription;

  TeacherViewModel({
    AcademicService? academicService,
    LocationService? locationService,
    FirebaseFirestore? firestore,
  })  : _academicService = academicService ?? AcademicService(),
        _locationService = locationService,
        _firestore = firestore;

  AcademicService get academicService => _academicService;
  LocationService get locationService => _locationService ?? LocationService();
  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;
  
  // Lecture Configuration
  String _department = AcademicService.departments.first;
  String get department => _department;

  String? _course;
  String? get course => _course;

  String? _batch;
  String? get batch => _batch;

  String? _semester;
  String? get semester => _semester;

  String? _subject;
  String? get subject => _subject;

  String _formattedTimeSlot = '09:00 AM - 10:00 AM (60 mins)';
  String get formattedTimeSlot => _formattedTimeSlot;

  // Active Session State
  bool _isSessionActive = false;
  bool get isSessionActive => _isSessionActive;

  String? _currentLectureId;
  String? get currentLectureId => _currentLectureId;

  int _attendeeCount = 0;
  int get attendeeCount => _attendeeCount;

  LocationData? _teacherLocation;
  LocationData? get teacherLocation => _teacherLocation;

  bool _isFetchingLocation = false;
  bool get isFetchingLocation => _isFetchingLocation;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void init(String? initialDepartment) {
    if (initialDepartment != null && initialDepartment.isNotEmpty) {
      _department = initialDepartment;
    }
    _initAcademicOptions();
    acquireTeacherLocation();
  }

  void _initAcademicOptions() {
    final courses = _academicService.getCoursesForDepartment(_department);
    if (courses.isNotEmpty) {
      _course = courses.first;
      _updateBatchesAndSubjects();
    }
  }

  void setDepartment(String newDept) {
    if (_department != newDept) {
      _department = newDept;
      final courses = _academicService.getCoursesForDepartment(_department);
      _course = courses.isNotEmpty ? courses.first : null;
      _updateBatchesAndSubjects();
      notifyListeners();
    }
  }

  void setCourse(String newCourse) {
    if (_course != newCourse) {
      _course = newCourse;
      _updateBatchesAndSubjects();
      notifyListeners();
    }
  }

  void setBatch(String newBatch) {
    if (_batch != newBatch) {
      _batch = newBatch;
      notifyListeners();
    }
  }

  void setSemester(String newSem) {
    if (_semester != newSem) {
      _semester = newSem;
      notifyListeners();
    }
  }

  void setSubject(String newSubj) {
    if (_subject != newSubj) {
      _subject = newSubj;
      notifyListeners();
    }
  }

  void setFormattedTimeSlot(String slot) {
    _formattedTimeSlot = slot;
    notifyListeners();
  }

  void _updateBatchesAndSubjects() {
    if (_course != null) {
      final batches = _academicService.generateBatches(_course!);
      final semesters = _academicService.generateSemesters(_course!);
      final subjects = _academicService.getSubjects(
        department: _department,
        selectedCourse: _course!,
      );

      _batch = batches.isNotEmpty ? batches.first : null;
      _semester = semesters.isNotEmpty ? semesters.first : null;
      _subject = subjects.isNotEmpty ? subjects.first : null;
    }
  }

  Future<void> acquireTeacherLocation() async {
    _isFetchingLocation = true;
    notifyListeners();

    try {
      _teacherLocation = await locationService.getCurrentLocation(forceRefresh: true);
    } catch (_) {
      // Handled gracefully
    } finally {
      _isFetchingLocation = false;
      notifyListeners();
    }
  }

  Future<bool> startLectureSession({
    required String teacherId,
    required String teacherName,
    required String teacherEmail,
  }) async {
    if (_subject == null || _course == null || _batch == null || _semester == null) {
      _errorMessage = 'Please configure all lecture parameters first.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_teacherLocation == null) {
        await acquireTeacherLocation();
      }

      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final prefix = teacherId.length >= 4 ? teacherId.substring(0, 4) : teacherId;
      final lectureId = 'LEC_${prefix}_${now.millisecondsSinceEpoch}';

      final lectureDoc = {
        'lectureId': lectureId,
        'classId': '$_course-$_batch-$_semester',
        'teacherId': teacherId,
        'teacherName': teacherName,
        'teacherEmail': teacherEmail,
        'department': _department,
        'course': _course,
        'batch': _batch,
        'semester': _semester,
        'subject': _subject,
        'timeSlot': _formattedTimeSlot,
        'date': dateStr,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
        if (_teacherLocation != null) 'location': _teacherLocation!.toMap(),
      };

      await firestore.collection('lectures').doc(lectureId).set(lectureDoc);

      _isSessionActive = true;
      _currentLectureId = lectureId;
      _attendeeCount = 0;

      _startListeningToAttendees(lectureId);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to start session: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startListeningToAttendees(String lectureId) {
    _attendeeSubscription?.cancel();
    _attendeeSubscription = firestore
        .collection('attendance')
        .where('lectureId', isEqualTo: lectureId)
        .snapshots()
        .listen((snapshot) {
      _attendeeCount = snapshot.docs.length;
      notifyListeners();
    });
  }

  Future<bool> endLectureSession() async {
    if (_currentLectureId == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await firestore.collection('lectures').doc(_currentLectureId).update({
        'status': 'completed',
        'endedAt': FieldValue.serverTimestamp(),
        'totalAttendance': _attendeeCount,
      });

      _attendeeSubscription?.cancel();
      _attendeeSubscription = null;
      _isSessionActive = false;
      _currentLectureId = null;
      return true;
    } catch (e) {
      _errorMessage = 'Failed to end lecture: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _attendeeSubscription?.cancel();
    super.dispose();
  }
}
