// FILE: rider_auth_screen.dart
// PURPOSE: Rider authentication screen with redesigned modern UI
// ALL BACKEND LOGIC, FIREBASE, GOOGLE SIGN-IN, AND API CALLS REMAIN UNCHANGED
// ONLY UI/UX HAS BEEN REDESIGNED

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'riders_dashboard.dart';
import 'rider_forgotpassword.dart';
import 'rider_emailverification.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class RiderAuthScreen extends StatefulWidget {
  const RiderAuthScreen({super.key});

  @override
  State<RiderAuthScreen> createState() => _RiderAuthScreenState();
}

class _RiderAuthScreenState extends State<RiderAuthScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // ⚠️ ALL BACKEND LOGIC - UNCHANGED
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // GoogleSignIn instance with custom configuration
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    signInOption: SignInOption.standard,
  );

  // API Base URL with dynamic switching
  static const bool _usePhysicalDevice = true;

  String get baseUrl {
    if (_usePhysicalDevice) {
      return 'http://10.0.2.2:3000/api';
    } else {
      return 'https://bikerzzz-backend.onrender.com/api';
    }
  }

  // Login form controllers
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();
  bool _isLoginPasswordVisible = false;
  bool _rememberMe = false;

  // Signup form controllers
  final TextEditingController _fullnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _agreeToTerms = false;

  DateTime? _selectedDate;

  // Loading states
  bool _isLoginLoading = false;
  bool _isSignupLoading = false;
  bool _isGoogleLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _animationController.forward();
    _checkAutoLogin();
  }

  // ⚠️ ALL METHODS BELOW REMAIN EXACTLY THE SAME - NO CHANGES
  Future<void> _initializeFirebase() async {
    try {
      await Firebase.initializeApp();
      print('✅ Firebase initialized successfully');
    } catch (e) {
      print('❌ Firebase initialization error: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _fullnameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkAutoLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('auth_token');

    if (token != null && token.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/verify-token'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['valid'] == true && mounted && data['user'] != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => RidersDashboard(userData: data['user']),
              ),
            );
          }
        }
      } catch (e) {
        await prefs.remove('auth_token');
        print('Auto-login failed: $e');
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF3B82F6),
              onPrimary: Colors.white,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  bool _isTokenStale(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;

      final payload = json.decode(
          utf8.decode(base64.decode(base64.normalize(parts[1])))
      );

      final issuedAt = payload['iat'] as int?;
      if (issuedAt == null) return false;

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final tokenAge = now - issuedAt;

      print('  Token age: $tokenAge seconds');
      return tokenAge > 300;
    } catch (e) {
      print('  Error checking token staleness: $e');
      return false;
    }
  }

  Future<void> _clearGoogleAuthCache() async {
    try {
      await GoogleSignIn().signOut();
      await _auth.signOut();
      if (Theme.of(context).platform == TargetPlatform.android) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      print('✓ Google auth cache cleared');
    } catch (e) {
      print('Error clearing auth cache: $e');
    }
  }

  Future<void> _performCompleteSignOut() async {
    try {
      await _googleSignIn.signOut();
      print('✓ Google signOut completed');
    } catch (e) {
      print('Google signOut error (ignored): $e');
    }

    try {
      await _googleSignIn.disconnect();
      print('✓ Google disconnect completed');
    } catch (e) {
      print('Google disconnect error (ignored): $e');
    }

    try {
      await _auth.signOut();
      print('✓ Firebase signOut completed');
    } catch (e) {
      print('Firebase signOut error (ignored): $e');
    }
  }

  Future<http.Response> _sendToBackendWithRetry({
    required String firebaseIdToken,
    required String email,
    required String fullname,
    required String googlePicture,
    int retryCount = 0,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/firebase');
      print('  Attempting to connect to: $uri');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'firebaseToken': firebaseIdToken,
          'email': email,
          'fullname': fullname,
          'googlePicture': googlePicture,
        }),
      ).timeout(const Duration(seconds: 30));

      return response;
    } on SocketException catch (e) {
      print('  SocketException: $e');
      if (retryCount < 2) {
        print('  Retry attempt ${retryCount + 1} after 1 second...');
        await Future.delayed(const Duration(seconds: 1));
        return _sendToBackendWithRetry(
          firebaseIdToken: firebaseIdToken,
          email: email,
          fullname: fullname,
          googlePicture: googlePicture,
          retryCount: retryCount + 1,
        );
      }
      rethrow;
    } catch (e) {
      if (retryCount < 2) {
        print('  Retry attempt ${retryCount + 1}...');
        await Future.delayed(const Duration(milliseconds: 500));
        return _sendToBackendWithRetry(
          firebaseIdToken: firebaseIdToken,
          email: email,
          fullname: fullname,
          googlePicture: googlePicture,
          retryCount: retryCount + 1,
        );
      }
      rethrow;
    }
  }

  Future<void> _handleSuccessfulSignIn(User firebaseUser) async {
    print('✓ Firebase sign-in successful');
    print('  Firebase UID: ${firebaseUser.uid}');
    print('  Email: ${firebaseUser.email}');
    print('  Email verified: ${firebaseUser.emailVerified}');

    await Future.delayed(const Duration(milliseconds: 500));

    String? firebaseIdToken = await firebaseUser.getIdToken(true);

    if (firebaseIdToken == null) {
      throw Exception('Failed to get Firebase ID token after refresh');
    }

    print('✓ Force refreshed Firebase ID Token (length: ${firebaseIdToken.length})');

    final response = await _sendToBackendWithRetry(
      firebaseIdToken: firebaseIdToken,
      email: firebaseUser.email ?? '',
      fullname: firebaseUser.displayName ?? '',
      googlePicture: firebaseUser.photoURL ?? '',
    );

    if (!mounted) return;

    final responseData = json.decode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      print('✓ Backend authentication successful');
      _showSnackBar('Google Sign-In successful!', const Color(0xFF10B981));

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', responseData['token']);

      if (mounted && responseData['user'] != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RidersDashboard(userData: responseData['user']),
          ),
        );
      }
    } else {
      print('❌ Backend error: ${responseData['message']}');
      _showSnackBar(responseData['message'] ?? 'Google Sign-In failed', const Color(0xFFEF4444));
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isGoogleLoading = true;
    });

    try {
      print('========================================');
      print('=== Google Sign-In with Firebase Started ===');
      print('========================================');

      await _performCompleteSignOut();
      await Future.delayed(const Duration(milliseconds: 1000));
      await _clearGoogleAuthCache();

      final freshGoogleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        signInOption: SignInOption.standard,
      );

      final GoogleSignInAccount? googleUser = await freshGoogleSignIn.signIn();

      if (googleUser == null) {
        print('✗ Google Sign-In cancelled by user');
        if (mounted) {
          _showSnackBar('Google Sign-In cancelled', const Color(0xFFEF4444));
        }
        return;
      }

      print('✓ Google Sign-In successful');
      print('  User: ${googleUser.email}');
      print('  Display Name: ${googleUser.displayName}');

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      if (googleAuth.idToken == null) {
        print('❌ ERROR: idToken is null');
        _showSnackBar('Failed to get authentication token', const Color(0xFFEF4444));
        return;
      }

      print('✓ Token received (length: ${googleAuth.idToken?.length ?? 0})');

      if (_isTokenStale(googleAuth.idToken!)) {
        print('⚠️ Token appears to be stale, refreshing...');
        await freshGoogleSignIn.signOut();
        await Future.delayed(const Duration(milliseconds: 500));

        final GoogleSignInAccount? retryUser = await freshGoogleSignIn.signIn();
        if (retryUser == null) {
          throw Exception('Re-authentication failed');
        }

        final GoogleSignInAuthentication retryAuth = await retryUser.authentication;
        if (retryAuth.idToken == null) {
          throw Exception('Failed to get fresh token');
        }

        print('✓ Fresh token obtained after re-authentication');

        final credential = GoogleAuthProvider.credential(
          accessToken: retryAuth.accessToken,
          idToken: retryAuth.idToken,
        );

        final UserCredential userCredential = await _auth.signInWithCredential(credential);
        final User? firebaseUser = userCredential.user;

        if (firebaseUser == null) {
          throw Exception('Firebase sign-in failed');
        }

        await _handleSuccessfulSignIn(firebaseUser);
      } else {
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final UserCredential userCredential = await _auth.signInWithCredential(credential);
        final User? firebaseUser = userCredential.user;

        if (firebaseUser == null) {
          throw Exception('Firebase sign-in failed');
        }

        await _handleSuccessfulSignIn(firebaseUser);
      }

    } on SocketException catch (e) {
      print('❌ SocketException: $e');
      _showSnackBar(
          'Cannot connect to server. Make sure backend is running on port 3000.\n\n'
              'Troubleshooting:\n'
              '1. Run "node server.js" in server directory\n'
              '2. Check if port 3000 is not blocked\n'
              '3. For emulator use 10.0.2.2, for physical device use your computer\'s IP',
          const Color(0xFFEF4444)
      );
    } catch (e) {
      print('❌ Google Sign-In error: $e');

      if (e is FirebaseAuthException) {
        if (e.message?.contains('stale') == true) {
          print('⚠️ Token still stale - showing re-authentication dialog');
          _showReauthenticationDialog();
        } else {
          _showSnackBar('Firebase error: ${e.message}', const Color(0xFFEF4444));
        }
      } else {
        _showSnackBar('Sign-In failed: ${e.toString()}', const Color(0xFFEF4444));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
      print('========================================');
    }
  }

  void _showReauthenticationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
            SizedBox(width: 8),
            Text('Sign-In Issue'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'There was an issue with Google Sign-In. This can happen due to:',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            Text('• Device time not synchronized', style: TextStyle(fontSize: 13)),
            Text('• Expired Google credentials', style: TextStyle(fontSize: 13)),
            Text('• Network connectivity issues', style: TextStyle(fontSize: 13)),
            SizedBox(height: 12),
            Text(
              'Please try the following:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 8),
            Text('1. Check your device date and time settings', style: TextStyle(fontSize: 13)),
            Text('2. Enable "Set automatically" for date & time', style: TextStyle(fontSize: 13)),
            Text('3. Clear Google Play Services data if issue persists', style: TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _isGoogleLoading = false;
              });
              await Future.delayed(const Duration(milliseconds: 300));
              _handleGoogleSignIn();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_loginEmailController.text.isEmpty || _loginPasswordController.text.isEmpty) {
      _showSnackBar('Please fill all fields', const Color(0xFFEF4444));
      return;
    }

    setState(() {
      _isLoginLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'email': _loginEmailController.text.trim(),
          'password': _loginPasswordController.text,
        }),
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        _showSnackBar(responseData['message'], const Color(0xFF10B981));

        if (_rememberMe) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', responseData['token']);
        }

        if (mounted && responseData['user'] != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RidersDashboard(userData: responseData['user']),
            ),
          );
        }
      } else {
        _showSnackBar(responseData['message'] ?? 'Login failed', const Color(0xFFEF4444));
      }
    } on SocketException {
      _showSnackBar('Cannot connect to server. Make sure backend is running on port 3000', const Color(0xFFEF4444));
    } catch (e) {
      _showSnackBar('Network error: Unable to connect to server', const Color(0xFFEF4444));
      print('Login error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoginLoading = false;
        });
      }
    }
  }

  Future<void> _handleSignup() async {
    if (_fullnameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _dobController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showSnackBar('Please fill all fields', const Color(0xFFEF4444));
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar('Passwords do not match', const Color(0xFFEF4444));
      return;
    }

    if (_passwordController.text.length < 6) {
      _showSnackBar('Password must be at least 6 characters', const Color(0xFFEF4444));
      return;
    }

    if (!_agreeToTerms) {
      _showSnackBar('Please agree to terms and conditions', const Color(0xFFEF4444));
      return;
    }

    setState(() {
      _isSignupLoading = true;
    });

    try {
      final otpResponse = await http.post(
        Uri.parse('$baseUrl/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': _emailController.text.trim().toLowerCase(),
        }),
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;

      final otpData = json.decode(otpResponse.body);

      if (otpResponse.statusCode == 200) {
        _showSnackBar('OTP sent to ${_emailController.text}', const Color(0xFF10B981));

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RiderEmailVerification(
              userData: {
                'fullname': _fullnameController.text.trim(),
                'email': _emailController.text.trim().toLowerCase(),
                'dob': _dobController.text,
                'password': _passwordController.text,
              },
              baseUrl: baseUrl,
            ),
          ),
        );
      } else {
        _showSnackBar(otpData['message'] ?? 'Failed to send OTP', const Color(0xFFEF4444));
      }
    } on SocketException {
      _showSnackBar('Cannot connect to server. Make sure backend is running', const Color(0xFFEF4444));
    } catch (e) {
      _showSnackBar('Network error: Unable to connect to server', const Color(0xFFEF4444));
      print('Signup error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSignupLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  void _navigateToForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RiderForgotPasswordScreen(),
      ),
    );
  }

  // ========== REDESIGNED UI ==========
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ========== REDESIGNED HEADER ==========
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Driver Authentication',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Brand Section
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF3B82F6).withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.directions_car,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Color(0xFF60A5FA), Color(0xFFA78BFA)],
                                ).createShader(bounds),
                                child: const Text(
                                  'Carzzz',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              const Text(
                                'Premium Car Rental',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w300,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // ========== REDESIGNED MAIN CARD ==========
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF1E293B).withOpacity(0.8),
                              const Color(0xFF0F172A).withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF3B82F6).withOpacity(0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF3B82F6).withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ========== REDESIGNED TAB BAR ==========
                              Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFF334155),
                                    width: 1,
                                  ),
                                ),
                                child: TabBar(
                                  controller: _tabController,
                                  indicator: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  labelColor: Colors.white,
                                  unselectedLabelColor: const Color(0xFF94A3B8),
                                  labelStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  unselectedLabelStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  dividerColor: Colors.transparent,
                                  tabs: const [
                                    Tab(text: 'Sign In'),
                                    Tab(text: 'Sign Up'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // ========== REDESIGNED TAB VIEWS ==========
                              SizedBox(
                                height: _tabController.index == 0 ? 420 : 550,
                                child: TabBarView(
                                  controller: _tabController,
                                  children: [
                                    _buildLoginTab(),
                                    _buildSignupTab(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ========== REDESIGNED FOOTER ==========
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Need help? ',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 14,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              _showSnackBar('Contact Support: support@carzzz.com', const Color(0xFF3B82F6));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Contact Support',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ========== REDESIGNED LOGIN TAB ==========
  Widget _buildLoginTab() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildModernTextField(
          controller: _loginEmailController,
          label: 'Email Address',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _buildModernTextField(
          controller: _loginPasswordController,
          label: 'Password',
          icon: Icons.lock_outline,
          obscureText: !_isLoginPasswordVisible,
          suffixIcon: IconButton(
            icon: Icon(
              _isLoginPasswordVisible ? Icons.visibility : Icons.visibility_off,
              color: const Color(0xFF64748B),
            ),
            onPressed: () {
              setState(() {
                _isLoginPasswordVisible = !_isLoginPasswordVisible;
              });
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Checkbox(
                  value: _rememberMe,
                  onChanged: (value) {
                    setState(() {
                      _rememberMe = value ?? false;
                    });
                  },
                  activeColor: const Color(0xFF3B82F6),
                  checkColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  side: const BorderSide(color: Color(0xFF334155)),
                ),
                const Text(
                  'Remember me',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: _navigateToForgotPassword,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  color: Color(0xFF60A5FA),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildModernButton(
          text: 'Sign In',
          isLoading: _isLoginLoading,
          onTap: _handleLogin,
        ),
        const SizedBox(height: 16),
        _buildModernSocialLogin(),
      ],
    );
  }

  // ========== REDESIGNED SIGNUP TAB ==========
  Widget _buildSignupTab() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildModernTextField(
          controller: _fullnameController,
          label: 'Full Name',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 16),
        _buildModernTextField(
          controller: _emailController,
          label: 'Email Address',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _buildModernTextField(
          controller: _dobController,
          label: 'Date of Birth',
          icon: Icons.calendar_today,
          readOnly: true,
          onTap: _selectDate,
          suffixIcon: const Icon(
            Icons.arrow_drop_down,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 16),
        _buildModernTextField(
          controller: _passwordController,
          label: 'Password',
          icon: Icons.lock_outline,
          obscureText: !_isPasswordVisible,
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              color: const Color(0xFF64748B),
            ),
            onPressed: () {
              setState(() {
                _isPasswordVisible = !_isPasswordVisible;
              });
            },
          ),
        ),
        const SizedBox(height: 16),
        _buildModernTextField(
          controller: _confirmPasswordController,
          label: 'Confirm Password',
          icon: Icons.lock_outline,
          obscureText: !_isConfirmPasswordVisible,
          suffixIcon: IconButton(
            icon: Icon(
              _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
              color: const Color(0xFF64748B),
            ),
            onPressed: () {
              setState(() {
                _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
              });
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Checkbox(
              value: _agreeToTerms,
              onChanged: (value) {
                setState(() {
                  _agreeToTerms = value ?? false;
                });
              },
              activeColor: const Color(0xFF3B82F6),
              checkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              side: const BorderSide(color: Color(0xFF334155)),
            ),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                  children: [
                    const TextSpan(text: 'I agree to the '),
                    TextSpan(
                      text: 'Terms of Service',
                      style: const TextStyle(
                        color: Color(0xFF60A5FA),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: const TextStyle(
                        color: Color(0xFF60A5FA),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildModernButton(
          text: 'Create Account',
          isLoading: _isSignupLoading,
          onTap: _handleSignup,
        ),
      ],
    );
  }

  // ========== REDESIGNED TEXT FIELD ==========
  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF334155),
          width: 1,
        ),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        readOnly: readOnly,
        onTap: onTap,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
          prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  // ========== REDESIGNED BUTTON ==========
  Widget _buildModernButton({
    required String text,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ========== REDESIGNED SOCIAL LOGIN ==========
  Widget _buildModernSocialLogin() {
    return Column(
      children: [
        const Row(
          children: [
            Expanded(
              child: Divider(
                color: Color(0xFF334155),
                thickness: 1,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Or continue with',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ),
            Expanded(
              child: Divider(
                color: Color(0xFF334155),
                thickness: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isGoogleLoading
                ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
              ),
            )
                : _buildModernSocialButton(
              icon: Icons.g_mobiledata,
              color: Colors.red,
              onTap: _handleGoogleSignIn,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModernSocialButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF334155),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Icon(icon, color: color, size: 30),
          ),
        ),
      ),
    );
  }
}

extension Base64Utils on String {
  static String normalize(String input) {
    switch (input.length % 4) {
      case 2:
        return '$input==';
      case 3:
        return '$input=';
      default:
        return input;
    }
  }
}