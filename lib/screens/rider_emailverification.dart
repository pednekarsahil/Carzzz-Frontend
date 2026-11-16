// FILE: rider_emailverification.dart
// PURPOSE: Email verification screen for rider registration

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'riders_dashboard.dart';

class RiderEmailVerification extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String baseUrl;

  const RiderEmailVerification({
    super.key,
    required this.userData,
    required this.baseUrl,
  });

  @override
  State<RiderEmailVerification> createState() => _RiderEmailVerificationState();
}

class _RiderEmailVerificationState extends State<RiderEmailVerification> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<TextEditingController> _otpControllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (index) => FocusNode());

  bool _isVerifying = false;
  bool _isResending = false;
  int _resendTimer = 30;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();

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

    // Start resend timer
    _startResendTimer();
  }

  void _startResendTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendTimer > 0) {
        setState(() {
          _resendTimer--;
        });
        _startResendTimer();
      } else if (mounted) {
        setState(() {
          _canResend = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  String _getOtp() {
    return _otpControllers.map((controller) => controller.text).join();
  }

  Future<void> _verifyOtp() async {
    String otp = _getOtp();

    if (otp.length != 6) {
      _showSnackBar('Please enter the 6-digit OTP', const Color(0xFFEF4444));
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      // Verify OTP
      final verifyResponse = await http.post(
        Uri.parse('${widget.baseUrl}/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': widget.userData['email'],
          'otp': otp,
        }),
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;

      final verifyData = json.decode(verifyResponse.body);

      if (verifyResponse.statusCode == 200) {
        // OTP verified, now create the account
        final signupResponse = await http.post(
          Uri.parse('${widget.baseUrl}/signup'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(widget.userData),
        ).timeout(const Duration(seconds: 30));

        if (!mounted) return;

        final signupData = json.decode(signupResponse.body);

        if (signupResponse.statusCode == 201) {
          _showSnackBar('Account created successfully!', const Color(0xFF10B981));

          // Save auth token if provided
          if (signupData['token'] != null) {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setString('auth_token', signupData['token']);
          }

          // Navigate to dashboard
          if (mounted && signupData['user'] != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => RidersDashboard(userData: signupData['user']),
              ),
            );
          }
        } else {
          _showSnackBar(signupData['message'] ?? 'Failed to create account', const Color(0xFFEF4444));
        }
      } else {
        _showSnackBar(verifyData['message'] ?? 'Invalid OTP', const Color(0xFFEF4444));
      }
    } catch (e) {
      _showSnackBar('Network error: Unable to connect to server', const Color(0xFFEF4444));
      print('Verification error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;

    setState(() {
      _isResending = true;
      _canResend = false;
    });

    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': widget.userData['email'],
        }),
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        _showSnackBar('OTP resent to ${widget.userData['email']}', const Color(0xFF10B981));

        // Clear OTP fields
        for (var controller in _otpControllers) {
          controller.clear();
        }
        _otpFocusNodes[0].requestFocus();

        // Reset timer
        setState(() {
          _resendTimer = 30;
        });
        _startResendTimer();
      } else {
        _showSnackBar(data['message'] ?? 'Failed to resend OTP', const Color(0xFFEF4444));
        setState(() {
          _canResend = true;
        });
      }
    } catch (e) {
      _showSnackBar('Network error: Unable to connect to server', const Color(0xFFEF4444));
      setState(() {
        _canResend = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDE1D5),
      body: Container(
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
                    children: [
                      // Back button
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6D6C8),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.arrow_back,
                                color: Color(0xFF2B1B12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5A1F),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF5A1F).withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.email_outlined,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Title
                      const Text(
                        'Verify Your Email',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2B1B12),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Subtitle
                      const Text(
                        'We\'ve sent a 6-digit verification code to',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF7D6C62),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.userData['email'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF5A1F),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // OTP Input Fields
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(6, (index) {
                            return SizedBox(
                              width: 50,
                              height: 60,
                              child: TextFormField(
                                controller: _otpControllers[index],
                                focusNode: _otpFocusNodes[index],
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                maxLength: 1,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2B1B12),
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  filled: true,
                                  fillColor: const Color(0xFFFAF7F4),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFE5D7C9)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFE5D7C9)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFFF5A1F), width: 2),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onChanged: (value) {
                                  if (value.length == 1 && index < 5) {
                                    _otpFocusNodes[index + 1].requestFocus();
                                  } else if (value.isEmpty && index > 0) {
                                    _otpFocusNodes[index - 1].requestFocus();
                                  }
                                },
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Verify Button
                      _buildButton(
                        text: 'Verify & Create Account',
                        color: const Color(0xFFFF5A1F),
                        isLoading: _isVerifying,
                        onTap: _verifyOtp,
                      ),
                      const SizedBox(height: 20),

                      // Resend OTP Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _canResend ? 'Didn\'t receive code? ' : 'Resend code in $_resendTimer seconds',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF7D6C62),
                            ),
                          ),
                          if (_canResend)
                            TextButton(
                              onPressed: _isResending ? null : _resendOtp,
                              child: _isResending
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5A1F)),
                                ),
                              )
                                  : const Text(
                                'Resend',
                                style: TextStyle(
                                  color: Color(0xFFFF5A1F),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Email info
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF7F4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5D7C9)),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: Color(0xFF7D6C62),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Please check your spam folder if you don\'t receive the email within a few minutes.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF7D6C62),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
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

  // ========== 3D BUTTON ==========
  Widget _buildButton({
    required String text,
    required Color color,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    const Color depthLipColor = Color(0xFFCC3F0C);
    const Color highlightColor = Color(0xFFFF7A47);
    const Color lowerFaceColor = Color(0xFFE64A12);

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
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
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [highlightColor, Color(0xFFFF5A1F), lowerFaceColor],
              stops: [0.0, 0.45, 1.0],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withOpacity(0.35),
              width: 1,
            ),
          ),
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
                      letterSpacing: 0.5,
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
    );
  }
}