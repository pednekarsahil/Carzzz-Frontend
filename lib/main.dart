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
        primaryColor: const Color(0xFFFF5A1F),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFFFF5A1F),
          secondary: const Color(0xFFD98A5C),
        ),
        fontFamily: 'Inter',
        scaffoldBackgroundColor: const Color(0xFFEDE1D5),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: IconThemeData(color: Color(0xFF2B1B12)),
        ),
      ),
      home: const ChoiceScreen(),
    );
  }
}