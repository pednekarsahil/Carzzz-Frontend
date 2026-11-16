// ============================================================
// FILE: partner_auth_screen.dart
// PURPOSE: Partner authentication screen with Google Sign-In
//
// DETAILS:
// - Provides Sign In and Sign Up tabs with smooth animations
// - Supports email/password login with "Remember Me" feature
// - Implements OTP verification for partner registration
// - Full Google Sign-In with Firebase token management
// - Auto-login checks for existing valid tokens on startup
// - Uses SharedPreferences for token persistence
// - Handles token refresh, retry logic, and error recovery
// - Dynamic API URL switching (local/production)
// - Modern dark theme UI with gradient styling
//
// DEPENDENCIES:
// - firebase_core, firebase_auth, google_sign_in
// - shared_preferences, http, dart:convert, dart:io
//
// NAVIGATION:
// - On success → Navigates to PartnerDashboard
// - Forgot Password → Navigates to PartnerForgotPasswordScreen
// ============================================================





import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'partner_dashboard.dart';
import 'partner_forgotpassword.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../widgets/app_icon_or_image.dart';

class PartnerAuthScreen extends StatefulWidget {
  const PartnerAuthScreen({super.key});

  @override
  State<PartnerAuthScreen> createState() => _PartnerAuthScreenState();
}

class _PartnerAuthScreenState extends State<PartnerAuthScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // GoogleSignIn instance with custom configuration
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    signInOption: SignInOption.standard,
  );

  // Optional brand logo controls (set e.g. 'assets/icon.png' or any PNG image)
  static const String? _brandLogoAsset = null;
  static const double _brandLogoSize = 24.0;
  static const double _brandLogoScale = 1.0;
  static const double _brandLogoOffsetX = 0.0; // Negative = Left, Positive = Right
  static const double _brandLogoOffsetY = 0.0; // Negative = Up, Positive = Down

  // Login form controllers
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();
  bool _isLoginPasswordVisible = false;
  bool _rememberMe = false;

  // Signup form controllers
  final TextEditingController _fullnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _agreeToTerms = false;

  // OTP verification controllers
  final TextEditingController _otpController = TextEditingController();
  bool _isOtpSent = false;
  String _tempBusinessEmail = '';

  // Loading states
  bool _isLoginLoading = false;
  bool _isSignupLoading = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _isGoogleLoading = false;

  // Business types
  final List<String> _businessTypes = [
    'car Rental',
    'car Repair',
    'car Store',
    'Tour Operator',
    'car Accessories',
    'Other'
  ];
  String? _selectedBusinessType;

  // API Base URL with dynamic switching
  static const bool _usePhysicalDevice = false;

  String get baseUrl {
    if (_usePhysicalDevice) {
      return 'http://10.0.2.2:3000/api';
    } else {
      return 'https://carzzz-frontend.onrender.com/api';
    }
  }

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
    _checkLoggedInStatus();
  }

  // ========== FIREBASE INITIALIZATION ==========
  Future<void> _initializeFirebase() async {
    try {
      await Firebase.initializeApp();
      print('✅ Partner Firebase initialized successfully');
    } catch (e) {
      print('❌ Partner Firebase initialization error: $e');
    }
  }

  // ========== AUTO LOGIN CHECK ==========
  Future<void> _checkLoggedInStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('partner_token');

    if (token != null && token.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/partner/verify-token'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['valid'] == true && mounted && data['partner'] != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => PartnerDashboard(partnerData: data['partner']),
              ),
            );
          }
        }
      } catch (e) {
        await prefs.remove('partner_token');
        print('Partner auto-login failed: $e');
      }
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
    _businessNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // ========== GOOGLE SIGN-IN HELPER METHODS ==========
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
      print('✓ Partner Google auth cache cleared');
    } catch (e) {
      print('Error clearing auth cache: $e');
    }
  }

  Future<void> _performCompleteSignOut() async {
    try {
      await _googleSignIn.signOut();
      print('✓ Partner Google signOut completed');
    } catch (e) {
      print('Google signOut error (ignored): $e');
    }

    try {
      await _googleSignIn.disconnect();
      print('✓ Partner Google disconnect completed');
    } catch (e) {
      print('Google disconnect error (ignored): $e');
    }

    try {
      await _auth.signOut();
      print('✓ Partner Firebase signOut completed');
    } catch (e) {
      print('Firebase signOut error (ignored): $e');
    }
  }

  Future<http.Response> _sendPartnerToBackendWithRetry({
    required String firebaseIdToken,
    required String email,
    required String fullname,
    required String googlePicture,
    int retryCount = 0,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/partner/auth/firebase');
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
        return _sendPartnerToBackendWithRetry(
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
        return _sendPartnerToBackendWithRetry(
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

  // =============================================
  // FIXED: _handlePartnerSuccessfulSignIn with token refresh retry
  // =============================================
  Future<void> _handlePartnerSuccessfulSignIn(User firebaseUser) async {
    print('✓ Partner Firebase sign-in successful');
    print('  Firebase UID: ${firebaseUser.uid}');
    print('  Email: ${firebaseUser.email}');
    print('  Email verified: ${firebaseUser.emailVerified}');

    // Wait a moment for token to stabilize
    await Future.delayed(const Duration(milliseconds: 500));

    // ========== FIX: Force refresh the token multiple times ==========
    String? firebaseIdToken;
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        firebaseIdToken = await firebaseUser.getIdToken(true);
        if (firebaseIdToken != null && firebaseIdToken.length > 100) {
          print('✅ Partner Firebase token refreshed successfully (attempt ${retryCount + 1})');
          break;
        }
      } catch (e) {
        print('⚠️ Partner Token refresh attempt ${retryCount + 1} failed: $e');
      }

      retryCount++;
      if (retryCount < maxRetries) {
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }

    if (firebaseIdToken == null || firebaseIdToken.length < 100) {
      throw Exception('Failed to get valid Firebase token after $maxRetries attempts');
    }

    print('✓ Partner Force refreshed Firebase ID Token (length: ${firebaseIdToken.length})');

    final response = await _sendPartnerToBackendWithRetry(
      firebaseIdToken: firebaseIdToken,
      email: firebaseUser.email ?? '',
      fullname: firebaseUser.displayName ?? '',
      googlePicture: firebaseUser.photoURL ?? '',
    );

    if (!mounted) return;

    final responseData = json.decode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      print('✓ Partner Backend authentication successful');
      _showSnackBar('Google Sign-In successful!', const Color(0xFF10B981));

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('partner_token', responseData['token']);

      if (mounted && responseData['partner'] != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PartnerDashboard(partnerData: responseData['partner']),
          ),
        );
      }
    } else {
      // ========== FIX: Handle 401 with retry ==========
      if (response.statusCode == 401) {
        final errorType = responseData['error'] ?? '';
        if (errorType == 'expired') {
          print('⚠️ Partner Token expired on backend, trying one more refresh...');
          final newToken = await firebaseUser.getIdToken(true);
          if (newToken != null && newToken != firebaseIdToken) {
            print('🔄 Retrying with newly refreshed token...');
            final retryResponse = await _sendPartnerToBackendWithRetry(
              firebaseIdToken: newToken,
              email: firebaseUser.email ?? '',
              fullname: firebaseUser.displayName ?? '',
              googlePicture: firebaseUser.photoURL ?? '',
            );
            if (retryResponse.statusCode == 200 || retryResponse.statusCode == 201) {
              final retryData = json.decode(retryResponse.body);
              if (retryData['success'] == true) {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.setString('partner_token', retryData['token']);
                if (mounted && retryData['partner'] != null) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PartnerDashboard(partnerData: retryData['partner']),
                    ),
                  );
                }
                return;
              }
            }
          }
        }
        print('❌ Partner Backend error: ${responseData['message']}');
        _showSnackBar(responseData['message'] ?? 'Google Sign-In failed', const Color(0xFFEF4444));
      } else {
        print('❌ Partner Backend error: ${responseData['message']}');
        _showSnackBar(responseData['message'] ?? 'Google Sign-In failed', const Color(0xFFEF4444));
      }
    }
  }

  // =============================================
  // FIXED: _handlePartnerGoogleSignIn with better token handling
  // =============================================
  Future<void> _handlePartnerGoogleSignIn() async {
    setState(() {
      _isGoogleLoading = true;
    });

    try {
      print('========================================');
      print('=== Partner Google Sign-In with Firebase Started ===');
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
        print('✗ Partner Google Sign-In cancelled by user');
        if (mounted) {
          _showSnackBar('Google Sign-In cancelled', const Color(0xFFEF4444));
        }
        return;
      }

      print('✓ Partner Google Sign-In successful');
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

        await _handlePartnerSuccessfulSignIn(firebaseUser);
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

        await _handlePartnerSuccessfulSignIn(firebaseUser);
      }

    } on SocketException catch (e) {
      print('❌ SocketException: $e');
      _showSnackBar(
          'Cannot connect to server. Make sure backend is running on port 3000.\n\n'
              'Troubleshooting:\n'
              '1. Run "py server.py" in server directory\n'
              '2. Check if port 3000 is not blocked\n'
              '3. For emulator use 10.0.2.2, for physical device use your computer\'s IP',
          const Color(0xFFEF4444)
      );
    } catch (e) {
      print('❌ Partner Google Sign-In error: $e');

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
            Text('Partner Sign-In Issue'),
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
          Container(
            decoration: BoxDecoration(
              image: const DecorationImage(
                image: AssetImage('assets/buttonsbg.png'),
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() {
                  _isGoogleLoading = false;
                });
                await Future.delayed(const Duration(milliseconds: 300));
                _handlePartnerGoogleSignIn();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Try Again'),
            ),
          ),
        ],
      ),
    );
  }

  // ========== OTP & REGISTRATION METHODS ==========
  Future<void> _sendOTP() async {
    if (_emailController.text.isEmpty) {
      _showSnackBar('Please enter business email', const Color(0xFFEF4444));
      return;
    }

    setState(() {
      _isSendingOtp = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/partner/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'businessEmail': _emailController.text.trim(),
        }),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        setState(() {
          _isOtpSent = true;
          _tempBusinessEmail = _emailController.text.trim();
        });
        _showSnackBar('OTP sent to ${_emailController.text}', const Color(0xFF10B981));
      } else {
        _showSnackBar(data['message'] ?? 'Failed to send OTP', const Color(0xFFEF4444));
      }
    } on SocketException {
      _showSnackBar('Cannot connect to server. Make sure backend is running.', const Color(0xFFEF4444));
    } catch (e) {
      _showSnackBar('Network error: $e', const Color(0xFFEF4444));
    } finally {
      if (mounted) {
        setState(() {
          _isSendingOtp = false;
        });
      }
    }
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.isEmpty) {
      _showSnackBar('Please enter OTP', const Color(0xFFEF4444));
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/partner/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'businessEmail': _tempBusinessEmail,
          'otp': _otpController.text.trim(),
        }),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        await _registerPartner();
      } else {
        _showSnackBar(data['message'] ?? 'Invalid OTP', const Color(0xFFEF4444));
      }
    } on SocketException {
      _showSnackBar('Cannot connect to server.', const Color(0xFFEF4444));
    } catch (e) {
      _showSnackBar('Network error: $e', const Color(0xFFEF4444));
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingOtp = false;
        });
      }
    }
  }

  Future<void> _registerPartner() async {
    if (_fullnameController.text.isEmpty ||
        _tempBusinessEmail.isEmpty ||
        _businessNameController.text.isEmpty ||
        _selectedBusinessType == null ||
        _phoneController.text.isEmpty ||
        _addressController.text.isEmpty ||
        _passwordController.text.isEmpty) {
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
      final response = await http.post(
        Uri.parse('$baseUrl/partner/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'fullname': _fullnameController.text.trim(),
          'businessEmail': _tempBusinessEmail,
          'businessName': _businessNameController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'businessAddress': _addressController.text.trim(),
          'businessType': _selectedBusinessType,
          'password': _passwordController.text,
          'agreedToTerms': _agreeToTerms,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 201 && data['success']) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('partner_token', data['token']);

        _showSnackBar('Registration successful!', const Color(0xFF10B981));

        final partnerData = {
          'fullname': data['partner']['fullname'],
          'businessName': data['partner']['businessName'],
          'email': data['partner']['businessEmail'],
          'phone': data['partner']['phoneNumber'],
          'address': data['partner']['businessAddress'],
          'businessType': data['partner']['businessType'],
        };

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PartnerDashboard(partnerData: partnerData),
          ),
        );
      } else {
        _showSnackBar(data['message'] ?? 'Registration failed', const Color(0xFFEF4444));
      }
    } on SocketException {
      _showSnackBar('Cannot connect to server.', const Color(0xFFEF4444));
    } catch (e) {
      _showSnackBar('Network error: $e', const Color(0xFFEF4444));
    } finally {
      if (mounted) {
        setState(() {
          _isSignupLoading = false;
        });
      }
    }
  }

  // ========== LOGIN METHOD ==========
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
        Uri.parse('$baseUrl/partner/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'businessEmail': _loginEmailController.text.trim(),
          'password': _loginPasswordController.text,
        }),
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('partner_token', data['token']);

        if (_rememberMe) {
          await prefs.setBool('remember_me', true);
          await prefs.setString('saved_email', _loginEmailController.text);
        } else {
          await prefs.remove('remember_me');
          await prefs.remove('saved_email');
        }

        _showSnackBar('Login successful!', const Color(0xFF10B981));

        final partnerData = {
          'fullname': data['partner']['fullname'],
          'businessName': data['partner']['businessName'],
          'email': data['partner']['businessEmail'],
          'phone': data['partner']['phoneNumber'],
          'address': data['partner']['businessAddress'],
          'businessType': data['partner']['businessType'],
        };

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PartnerDashboard(partnerData: partnerData),
          ),
        );
      } else {
        _showSnackBar(data['message'] ?? 'Login failed', const Color(0xFFEF4444));
      }
    } on SocketException {
      _showSnackBar('Cannot connect to server. Make sure backend is running on port 3000', const Color(0xFFEF4444));
    } catch (e) {
      _showSnackBar('Network error: Unable to connect to server', const Color(0xFFEF4444));
      print('Partner login error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoginLoading = false;
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

  // ========== UI BUILD ==========
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDE1D5),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFEDE1D5),
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
                      // Header
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6D6C8),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.arrow_back,
                                color: Color(0xFF2B1B12),
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),

                        ],
                      ),
                      const SizedBox(height: 32),

// Brand Section - Centered
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min, // Makes Row take minimum space
                          children: [

                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ShaderMask(
                                  shaderCallback: (bounds) => const LinearGradient(
                                    colors: [Color(0xFF2B1B12), Color(0xFFFF5A1F)],
                                  ).createShader(bounds),
                                  child: const Text(
                                    'Carzzz Partner',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                const Text(
                                  'Grow Your Business',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF7D6C62),
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ========== 3D MAIN CARD ==========
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFC7B3A1), // Deep solid 3D extrusion base lip
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            // Deep contact shadow under depth lip
                            const BoxShadow(
                              color: Color(0x332B1B12),
                              blurRadius: 8,
                              offset: Offset(0, 7),
                            ),
                            // Wide ambient 3D elevation shadow
                            BoxShadow(
                              color: Colors.black.withOpacity(0.10),
                              blurRadius: 24,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.only(bottom: 7.0), // 3D depth lip extrusion
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFFFFFFFF), // Crisp top light reflection
                                Color(0xFFFAF7F4), // Main face body
                                Color(0xFFF3ECE4), // Subtle bottom ambient shade
                              ],
                              stops: [0.0, 0.40, 1.0],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFFE2D3C4),
                              width: 1.5,
                            ),
                          ),
                          child: Stack(
                            children: [
                              // Specular highlight line along top rim
                              Positioned(
                                top: 0,
                                left: 24,
                                right: 24,
                                height: 1.5,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.0),
                                        Colors.white.withOpacity(0.9),
                                        Colors.white.withOpacity(0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // ========== 3D TAB BAR ==========
                                    Container(
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEDE4DC),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0xFFDFD1C4),
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.04),
                                            blurRadius: 3,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: TabBar(
                                        controller: _tabController,
                                        indicator: const _ThreeDTabIndicator(),
                                        indicatorSize: TabBarIndicatorSize.tab,
                                        labelColor: Colors.white,
                                        unselectedLabelColor: const Color(0xFF7D6C62),
                                        labelStyle: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          shadows: [
                                            Shadow(
                                              color: Color(0x664A1400),
                                              offset: Offset(0, 1),
                                              blurRadius: 2,
                                            ),
                                          ],
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

                                    // Tab Views
                                    SizedBox(
                                      height: _tabController.index == 0 ? 500 : 750,
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
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Footer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Need help? ',
                            style: TextStyle(
                              color: Color(0xFF7D6C62),
                              fontSize: 14,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              _showSnackBar('Partner Support: partners@carrzz.com', const Color(0xFFFF5A1F));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5A1F),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Partner Support',
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

  // ========== LOGIN TAB ==========
  Widget _buildLoginTab() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildModernTextField(
          controller: _loginEmailController,
          label: 'Business Email',
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
              color: const Color(0xFF7D6C62),
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
                  activeColor: const Color(0xFFFF5A1F),
                  checkColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  side: const BorderSide(color: Color(0xFFBDA999)),
                ),
                const Text(
                  'Remember me',
                  style: TextStyle(
                    color: Color(0xFF7D6C62),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PartnerForgotPasswordScreen(),
                  ),
                );
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  color: Color(0xFFFF5A1F),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildModernButton(
          text: 'Partner Login',
          isLoading: _isLoginLoading,
          onTap: _handleLogin,
        ),
        const SizedBox(height: 16),

        // Social Login - Google Sign-In
        Column(
          children: [
            const Row(
              children: [
                Expanded(
                  child: Divider(
                    color: Color(0xFFE5D7C9),
                    thickness: 1,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Or continue with',
                    style: TextStyle(color: Color(0xFF7D6C62), fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: Color(0xFFE5D7C9),
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
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5A1F)),
                  ),
                )
                    : _buildModernSocialButton(
                  icon: Icons.g_mobiledata,
                  color: const Color(0xFFFF5A1F),
                  onTap: _handlePartnerGoogleSignIn,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Info Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7E9DF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFE5D7C9),
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFFFF5A1F), size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Application is currently under construction.🚧 \n Please use Google Sign-In to access the application. ',
                  style: TextStyle(
                    color: Color(0xFF7D6C62),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ========== SIGNUP TAB ==========
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

        // Email with OTP Verification
        _buildModernTextField(
          controller: _emailController,
          label: 'Business Email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          readOnly: _isOtpSent,
          suffixIcon: _isOtpSent
              ? null
              : Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _isSendingOtp
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5A1F)),
              ),
            )
                : TextButton(
              onPressed: _sendOTP,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Send OTP',
                style: TextStyle(
                  color: Color(0xFFFF5A1F),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),

        if (_isOtpSent) ...[
          const SizedBox(height: 16),
          _buildModernTextField(
            controller: _otpController,
            label: 'Enter OTP',
            icon: Icons.security,
            keyboardType: TextInputType.number,
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _isVerifyingOtp
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5A1F)),
                ),
              )
                  : TextButton(
                onPressed: _verifyOTP,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Verify',
                  style: TextStyle(
                    color: Color(0xFFFF5A1F),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        _buildModernTextField(
          controller: _businessNameController,
          label: 'Business Name',
          icon: Icons.business_outlined,
        ),
        const SizedBox(height: 16),

        // Business Type Dropdown
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5EFE9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE5D7C9),
              width: 1,
            ),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedBusinessType,
            dropdownColor: const Color(0xFFFAF7F4),
            style: const TextStyle(color: Color(0xFF2B1B12)),
            decoration: const InputDecoration(
              labelText: 'Business Type',
              labelStyle: TextStyle(color: Color(0xFF7D6C62)),
              prefixIcon: Icon(Icons.category_outlined, color: Color(0xFFFF5A1F), size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            items: _businessTypes.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type, style: const TextStyle(color: Color(0xFF2B1B12))),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedBusinessType = value;
              });
            },
            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF7D6C62)),
          ),
        ),
        const SizedBox(height: 16),

        _buildModernTextField(
          controller: _phoneController,
          label: 'Phone Number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),

        _buildModernTextField(
          controller: _addressController,
          label: 'Business Address',
          icon: Icons.location_on_outlined,
          maxLines: 2,
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
              color: const Color(0xFF7D6C62),
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
              color: const Color(0xFF7D6C62),
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
              activeColor: const Color(0xFFFF5A1F),
              checkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              side: const BorderSide(color: Color(0xFFBDA999)),
            ),
            Expanded(
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(
                    color: Color(0xFF7D6C62),
                    fontSize: 13,
                  ),
                  children: [
                    TextSpan(text: 'I agree to the '),
                    TextSpan(
                      text: 'Partner Terms',
                      style: TextStyle(
                        color: Color(0xFFFF5A1F),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Business Agreement',
                      style: TextStyle(
                        color: Color(0xFFFF5A1F),
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
          text: 'Register Business',
          isLoading: _isSignupLoading,
          onTap: _handleSignup,
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7E9DF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFE5D7C9),
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.star, color: Color(0xFFFF5A1F), size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Join as a partner to access exclusive benefits, business tools, and a growing customer base.',
                  style: TextStyle(
                    color: Color(0xFF2B1B12),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ========== UI COMPONENTS ==========
  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    bool readOnly = false,
    VoidCallback? onTap,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5EFE9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5D7C9),
          width: 1,
        ),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        readOnly: readOnly,
        onTap: onTap,
        maxLines: maxLines,
        style: const TextStyle(color: Color(0xFF2B1B12)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF7D6C62)),
          prefixIcon: Icon(icon, color: const Color(0xFFFF5A1F), size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  // ========== 3D BUTTON ==========
  Widget _buildModernButton({
    required String text,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    const Color baseColor = Color(0xFFFF5A1F);
    const Color depthLipColor = Color(0xFFCC3F0C);
    const Color highlightColor = Color(0xFFFF7A47);
    const Color lowerFaceColor = Color(0xFFE64A12);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 4.5),
      decoration: BoxDecoration(
        color: depthLipColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: depthLipColor.withOpacity(0.40),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [highlightColor, baseColor, lowerFaceColor],
            stops: [0.0, 0.45, 1.0],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withOpacity(0.35),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
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
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          shadows: [
                            Shadow(
                              color: Color(0x554A1400),
                              offset: Offset(0, 1),
                              blurRadius: 2,
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

  // ========== 3D SOCIAL BUTTON ==========
  Widget _buildModernSocialButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 52,
      height: 52,
      padding: const EdgeInsets.only(bottom: 3.5),
      decoration: BoxDecoration(
        color: const Color(0xFFD6C6B8), // 3D depth lip
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0x2E2B1B12),
            blurRadius: 6,
            offset: const Offset(0, 3.5),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFFAF7F4),
              Color(0xFFF3ECE4),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFE2D3C4),
            width: 1.2,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Center(
              child: Icon(icon, color: color, size: 30),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSignup() async {
    if (!_isOtpSent) {
      await _sendOTP();
    }
  }
}

// ========== BASE64 UTILITY ==========
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

// ========== 3D ORANGE TAB INDICATOR (SIGN IN / SIGN UP) ==========
class _ThreeDTabIndicator extends Decoration {
  final Color baseColor;
  final Color depthLipColor;
  final Color highlightColor;
  final Color lowerFaceColor;
  final double depth;

  const _ThreeDTabIndicator({
    this.baseColor = const Color(0xFFFF5A1F),
    this.depthLipColor = const Color(0xFFCC3F0C),
    this.highlightColor = const Color(0xFFFF7A47),
    this.lowerFaceColor = const Color(0xFFE64A12),
    this.depth = 3.5,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _ThreeDTabIndicatorPainter(this, onChanged);
  }
}

class _ThreeDTabIndicatorPainter extends BoxPainter {
  final _ThreeDTabIndicator decoration;

  _ThreeDTabIndicatorPainter(this.decoration, VoidCallback? onChanged)
      : super(onChanged);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final Rect rect = offset & (configuration.size ?? Size.zero);
    if (rect.isEmpty) return;

    // Inset slightly inside the tab bar container
    final insets = const EdgeInsets.all(4.0);
    final targetRect = insets.deflateRect(rect);
    const radius = Radius.circular(11);

    final double faceHeight = targetRect.height - decoration.depth;
    final topRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        targetRect.left,
        targetRect.top,
        targetRect.width,
        faceHeight,
      ),
      radius,
    );
    final depthRRect = topRRect.shift(Offset(0, decoration.depth));

    // 1. Drop shadow under 3D depth lip
    final shadowPaint = Paint()
      ..color = decoration.depthLipColor.withOpacity(0.42)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawRRect(depthRRect.shift(const Offset(0, 3)), shadowPaint);

    // 2. 3D Depth lip extrusion (solid base volume)
    for (double dy = decoration.depth; dy >= 1.0; dy -= 0.5) {
      canvas.drawRRect(
        topRRect.shift(Offset(0, dy)),
        Paint()
          ..color = decoration.depthLipColor
          ..style = PaintingStyle.fill,
      );
    }

    // 3. Top Face Gradient (volumetric 3D lighting reflection)
    final facePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          decoration.highlightColor,
          decoration.baseColor,
          decoration.lowerFaceColor,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(topRRect.outerRect)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(topRRect, facePaint);

    // 4. Subtle top border highlight
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(topRRect, borderPaint);
  }
}