import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

// main.dart file
import 'screens/choice_screen.dart';

void main() async {
  // IMPORTANT: Ensure Flutter is initialized for async operations
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase - This MUST happen before runApp()
  try {
    await Firebase.initializeApp();
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization error: $e');
    // You can show an error screen if Firebase fails to initialize
  }

  // Now run the app
  runApp(const CarzzApp());
}

class CarzzApp extends StatelessWidget {
  const CarzzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'carrzz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF3B82F6),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF3B82F6),
          secondary: const Color(0xFF10B981),
        ),
        fontFamily: 'Inter',
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: IconThemeData(color: Color(0xFF1F2937)),
        ),
      ),
      home: const ChoiceScreen(),
    );
  }
}