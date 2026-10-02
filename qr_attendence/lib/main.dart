import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:qr_attendence/firebase_options.dart';
import 'package:qr_attendence/screens/login_screen.dart';
import 'package:qr_attendence/screens/signup_screen.dart';
import 'package:qr_attendence/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Roll',
      theme: AppTheme.lightTheme,
      initialRoute: '/login',
      routes: {
       // '/home': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
        // '/student': (context) => const StudentScreen(),
        '/signup': (context) => const SignupScreen(),
      },
    );
  }
}
