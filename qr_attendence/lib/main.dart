import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:qr_attendence/firebase_options.dart';
import 'package:qr_attendence/screens/login_screen.dart';
import 'package:qr_attendence/screens/signup_screen.dart';
import 'package:qr_attendence/screens/student_screen.dart';
import 'package:qr_attendence/screens/teacher_dashboard.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QR Attendance',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/login',
      routes: {
        '/home': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/student': (context) => const StudentScreen(),
        '/teacher_dashboard': (context) => const TeacherDashboard(),
        '/signup': (context) => const SignupScreen(),
      },
    );
  }
}
