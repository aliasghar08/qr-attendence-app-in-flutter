import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_attendence/viewmodels/auth_viewmodel.dart';
import 'package:qr_attendence/viewmodels/history_viewmodel.dart';
import 'package:qr_attendence/viewmodels/student_viewmodel.dart';
import 'package:qr_attendence/viewmodels/teacher_viewmodel.dart';
import 'package:qr_attendence/widgets/responsive_layout.dart';

void main() {
  group('AuthViewModel Tests', () {
    test('Initial state is correct', () {
      final vm = AuthViewModel();
      expect(vm.isLoading, isFalse);
      expect(vm.isPasswordVisible, isFalse);
      expect(vm.selectedRole, equals('student'));
      expect(vm.errorMessage, isNull);
    });

    test('Password visibility toggle updates state', () {
      final vm = AuthViewModel();
      expect(vm.isPasswordVisible, isFalse);

      vm.togglePasswordVisibility();
      expect(vm.isPasswordVisible, isTrue);

      vm.togglePasswordVisibility();
      expect(vm.isPasswordVisible, isFalse);
    });

    test('Role selection updates state', () {
      final vm = AuthViewModel();
      vm.setSelectedRole('teacher');
      expect(vm.selectedRole, equals('teacher'));

      vm.setSelectedRole('student');
      expect(vm.selectedRole, equals('student'));
    });
  });

  group('TeacherViewModel Tests', () {
    test('Academic options initialization and updates work correctly', () {
      final vm = TeacherViewModel();
      vm.init('Computer Science');

      expect(vm.department, equals('Computer Science'));
      expect(vm.course, isNotNull);
      expect(vm.batch, isNotNull);
      expect(vm.semester, isNotNull);
      expect(vm.subject, isNotNull);

      // Change time slot
      vm.setFormattedTimeSlot('11:00 AM - 12:00 PM (60 mins)');
      expect(vm.formattedTimeSlot, equals('11:00 AM - 12:00 PM (60 mins)'));
    });
  });

  group('HistoryViewModel Tests', () {
    test('Search and filter matching works accurately', () {
      final vm = HistoryViewModel();
      final lecture = {
        'subject': 'Operating Systems',
        'course': 'BS Computer Science',
        'batch': '2022-2026',
        'date': '2026-10-04',
        'timeSlot': '09:00 AM - 10:00 AM',
      };

      // Empty search matches everything
      expect(vm.matchesFilter(lecture), isTrue);

      // Matching query
      vm.setSearchQuery('operating');
      expect(vm.matchesFilter(lecture), isTrue);

      vm.setSearchQuery('2022');
      expect(vm.matchesFilter(lecture), isTrue);

      // Non-matching query
      vm.setSearchQuery('Calculus');
      expect(vm.matchesFilter(lecture), isFalse);

      // Clearing search
      vm.clearSearch();
      expect(vm.searchQuery, isEmpty);
      expect(vm.matchesFilter(lecture), isTrue);
    });
  });

  group('StudentViewModel Tests', () {
    test('Initial states and resetting messages', () {
      final vm = StudentViewModel();
      expect(vm.isProcessing, isFalse);
      expect(vm.isFetchingLocation, isFalse);
      expect(vm.isTorchOn, isFalse);
      expect(vm.lastErrorMessage, isNull);
      expect(vm.lastSuccessDetails, isNull);

      vm.resetMessages();
      expect(vm.lastErrorMessage, isNull);
      expect(vm.lastSuccessDetails, isNull);
    });
  });

  group('ResponsiveLayout Tests', () {
    testWidgets('gridColumns returns appropriate column counts', (tester) async {
      int colsMobile = 0;
      int colsTablet = 0;
      int colsDesktop = 0;

      // Test mobile size (400px wide)
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: Builder(
              builder: (context) {
                colsMobile = ResponsiveLayout.gridColumns(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      // Test tablet size (800px wide)
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 1000)),
            child: Builder(
              builder: (context) {
                colsTablet = ResponsiveLayout.gridColumns(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      // Test desktop/large tablet size (1200px wide)
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1200, 1000)),
            child: Builder(
              builder: (context) {
                colsDesktop = ResponsiveLayout.gridColumns(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(colsMobile, equals(1));
      expect(colsTablet, equals(2));
      expect(colsDesktop, equals(3));
    });
  });
}
