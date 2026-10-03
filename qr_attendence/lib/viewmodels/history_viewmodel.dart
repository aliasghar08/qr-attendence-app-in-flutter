import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryViewModel extends ChangeNotifier {
  final FirebaseFirestore? _firestore;

  HistoryViewModel({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  bool _isLoadingAttendees = false;
  bool get isLoadingAttendees => _isLoadingAttendees;

  List<Map<String, dynamic>> _currentLectureAttendees = [];
  List<Map<String, dynamic>> get currentLectureAttendees => _currentLectureAttendees;

  String? _attendeeError;
  String? get attendeeError => _attendeeError;

  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase().trim();
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  bool matchesFilter(Map<String, dynamic> lecture) {
    if (_searchQuery.isEmpty) return true;

    final subject = (lecture['subject'] ?? '').toString().toLowerCase();
    final course = (lecture['course'] ?? '').toString().toLowerCase();
    final batch = (lecture['batch'] ?? '').toString().toLowerCase();
    final date = (lecture['date'] ?? '').toString().toLowerCase();
    final timeSlot = (lecture['timeSlot'] ?? '').toString().toLowerCase();

    return subject.contains(_searchQuery) ||
        course.contains(_searchQuery) ||
        batch.contains(_searchQuery) ||
        date.contains(_searchQuery) ||
        timeSlot.contains(_searchQuery);
  }

  Future<void> fetchAttendeesForLecture(String lectureId) async {
    _isLoadingAttendees = true;
    _attendeeError = null;
    _currentLectureAttendees = [];
    notifyListeners();

    try {
      final snap = await firestore
          .collection('attendance')
          .where('lectureId', isEqualTo: lectureId)
          .get();

      _currentLectureAttendees = snap.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      _attendeeError = 'Failed to load attendees: ${e.toString()}';
    } finally {
      _isLoadingAttendees = false;
      notifyListeners();
    }
  }
}
