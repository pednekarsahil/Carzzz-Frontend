// FILE: rider_forgotpassword.dart
// PURPOSE: Rider forgot password screen with email verification and OTP functionality
// THEME: Blue theme matching rider dashboard (Color(0xFF3B82F6))

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RiderForgotPasswordScreen extends StatefulWidget {
  const RiderForgotPasswordScreen({super.key});

  @override
  State<RiderForgotPasswordScreen> createState() => _RiderForgotPasswordScreenState();
}

class _RiderForgotPasswordScreenState extends State<RiderForgotPasswordScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Step tracking: 1 = Enter Email, 2 = Enter OTP, 3 = Reset Password
  int _currentStep = 1;

  // Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // Password visibility
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // Loading states
  bool _isLoading = false;
  bool _isResendingOtp = false;

  // OTP resend timer
  int _resendTimer = 0;
  bool _canResendOtp = false;

  // Terracotta orange theme color
  final Color _primaryColor = const Color(0xFFFF5A1F);

  // CHANGE THIS MANUALLY:
// Set to false for emulator, true for physical device
  static const bool _usePhysicalDevice = false;  // ← Change this

// Get base URL based on your selection
  String get _baseUrl {
    if (_usePhysicalDevice) {
      return 'http://10.0.2.2:3000/api';  // Your computer IP for physical device
    } else {
      return 'https://carzzz-frontend.onrender.com/api';     // Emulator IP
    }
  }
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _startResendTimer() {
    setState(() {
      _resendTimer = 60;
      _canResendOtp = false;
    });

    Future.delayed(const Duration(seconds: 1), _updateTimer);
  }

  void _updateTimer() {
    if (_resendTimer > 0) {
      setState(() {
        _resendTimer--;
      });
      Future.delayed(const Duration(seconds: 1), _updateTimer);
    } else {
      setState(() {
        _canResendOtp = true;
      });
    }
  }

  Future<void> _sendOtp() async {
    if (_emailController.text.isEmpty) {
      _showSnackBar('Please enter your email address', const Color(0xFFEF4444));
      return;
    }

    if (!_isValidEmail(_emailController.text)) {
      _showSnackBar('Please enter a valid email address', const Color(0xFFEF4444));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (!mounted) return;

        _showSnackBar('OTP sent to ${_emailController.text}', _primaryColor);
        setState(() {
          _currentStep = 2;
        });
        _startResendTimer();

        // Show test OTP if available (for development)
        if (data['testOtp'] != null) {
          print('⚠️ Test OTP: ${data['testOtp']}');
          _showSnackBar('Test OTP: ${data['testOtp']}', _primaryColor);
        }
      } else {
        _showSnackBar(
          data['message'] ?? 'Failed to send OTP. Please try again.',
          const Color(0xFFEF4444),
        );
      }
    } catch (e) {
      print('Error sending OTP: $e');
      _showSnackBar(
        'Network error. Please check your connection.',
        const Color(0xFFEF4444),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.isEmpty) {
      _showSnackBar('Please enter the OTP', const Color(0xFFEF4444));
      return;
    }

    if (_otpController.text.length != 6) {
      _showSnackBar('Please enter a valid 6-digit OTP', const Color(0xFFEF4444));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'otp': _otpController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (!mounted) return;

        _showSnackBar('OTP verified successfully!', _primaryColor);
        setState(() {
          _currentStep = 3;
        });
      } else {
        _showSnackBar(
          data['message'] ?? 'Invalid OTP. Please try again.',
          const Color(0xFFEF4444),
        );
      }
    } catch (e) {
      print('Error verifying OTP: $e');
      _showSnackBar(
        'Network error. Please check your connection.',
        const Color(0xFFEF4444),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_newPasswordController.text.isEmpty) {
      _showSnackBar('Please enter a new password', const Color(0xFFEF4444));
      return;
    }

    if (_newPasswordController.text.length < 6) {
      _showSnackBar('Password must be at least 6 characters', const Color(0xFFEF4444));
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnackBar('Passwords do not match', const Color(0xFFEF4444));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Reset password using OTP verification
      final resetResponse = await http.post(
        Uri.parse('$_baseUrl/reset-password-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'newPassword': _newPasswordController.text.trim(),
        }),
      );

      final resetData = jsonDecode(resetResponse.body);

      if (resetResponse.statusCode == 200 && resetData['success'] == true) {
        _showSnackBar(
          'Password reset successful! Please login with your new password.',
          _primaryColor,
        );

        // Navigate back to login after delay
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      } else {
        _showSnackBar(
          resetData['message'] ?? 'Failed to reset password. Please try again.',
          const Color(0xFFEF4444),
        );
      }
    } catch (e) {
      print('Error resetting password: $e');
      _showSnackBar(
        'Network error. Please check your connection.',
        const Color(0xFFEF4444),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResendOtp) return;

    setState(() {
      _isResendingOtp = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (mounted) {
          _showSnackBar('New OTP sent to ${_emailController.text}', _primaryColor);
          _startResendTimer();

          if (data['testOtp'] != null) {
            print('⚠️ New Test OTP: ${data['testOtp']}');
            _showSnackBar('Test OTP: ${data['testOtp']}', _primaryColor);
          }
        }
      } else {
        if (mounted) {
          _showSnackBar(
            data['message'] ?? 'Failed to resend OTP. Please try again.',
            const Color(0xFFEF4444),
          );
        }
      }
    } catch (e) {
      print('Error resending OTP: $e');
      if (mounted) {
        _showSnackBar(
          'Network error. Please check your connection.',
          const Color(0xFFEF4444),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResendingOtp = false;
        });
      }
    }
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepCircle(1, 'Email'),
        Container(
          width: 40,
          height: 2,
          color: _currentStep >= 2 ? _primaryColor : const Color(0xFFE5D7C9),
        ),
        _buildStepCircle(2, 'OTP'),
        Container(
          width: 40,
          height: 2,
          color: _currentStep >= 3 ? _primaryColor : const Color(0xFFE5D7C9),
        ),
        _buildStepCircle(3, 'Reset'),
      ],
    );
  }

  Widget _buildStepCircle(int step, String label) {
    bool isActive = _currentStep >= step;
    bool isCompleted = _currentStep > step;

    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? _primaryColor : const Color(0xFFE6D6C8),
            border: isActive ? null : Border.all(color: const Color(0xFFD5C3B3)),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
              step.toString(),
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF7D6C62),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? _primaryColor : const Color(0xFF7D6C62),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildEnterEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Forgot Password?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2B1B12),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter your email address and we\'ll send you a verification code to reset your password.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF7D6C62),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),

        // Email Field
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5EFE9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5D7C9)),
          ),
          child: TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Color(0xFF2B1B12)),
            decoration: InputDecoration(
              labelText: 'Email Address',
              labelStyle: const TextStyle(color: Color(0xFF7D6C62)),
              prefixIcon: Icon(Icons.email_outlined, color: _primaryColor, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              hintText: 'you@example.com',
              hintStyle: const TextStyle(color: Color(0xFF9A8B82), fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Send OTP Button
        _buildButton(
          text: 'Send Verification Code',
          color: _primaryColor,
          isLoading: _isLoading,
          onTap: _sendOtp,
        ),

        const SizedBox(height: 16),

        // Back to Login
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Remember your password? ',
              style: TextStyle(color: Color(0xFF7D6C62), fontSize: 14),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'Back to Login',
                style: TextStyle(
                  color: _primaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEnterOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Verify Your Email',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2B1B12),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'We\'ve sent a 6-digit verification code to',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF7D6C62),
          ),
        ),
        Text(
          _emailController.text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _primaryColor,
          ),
        ),
        const SizedBox(height: 24),

        // OTP Field
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5EFE9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5D7C9)),
          ),
          child: TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: const TextStyle(color: Color(0xFF2B1B12), fontSize: 18, letterSpacing: 2),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              labelText: 'Verification Code',
              labelStyle: const TextStyle(color: Color(0xFF7D6C62)),
              prefixIcon: Icon(Icons.security, color: _primaryColor, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              counterText: '',
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Resend OTP
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Didn\'t receive code? ',
              style: TextStyle(color: Color(0xFF7D6C62), fontSize: 14),
            ),
            _canResendOtp
                ? TextButton(
              onPressed: _resendOtp,
              child: _isResendingOtp
                  ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                ),
              )
                  : Text(
                'Resend',
                style: TextStyle(
                  color: _primaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
                : Text(
              'Resend in $_resendTimer sec',
              style: const TextStyle(
                color: Color(0xFF9A8B82),
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Verify OTP Button
        _buildButton(
          text: 'Verify OTP',
          color: _primaryColor,
          isLoading: _isLoading,
          onTap: _verifyOtp,
        ),

        const SizedBox(height: 16),

        // Back to Email Step
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _currentStep = 1;
                  _otpController.clear();
                });
              },
              child: const Text(
                '← Back to Email',
                style: TextStyle(
                  color: Color(0xFF7D6C62),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResetPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Create New Password',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2B1B12),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your new password must be different from previously used passwords.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF7D6C62),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),

        // New Password Field
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5EFE9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5D7C9)),
          ),
          child: TextFormField(
            controller: _newPasswordController,
            obscureText: !_isNewPasswordVisible,
            style: const TextStyle(color: Color(0xFF2B1B12)),
            decoration: InputDecoration(
              labelText: 'New Password',
              labelStyle: const TextStyle(color: Color(0xFF7D6C62)),
              prefixIcon: Icon(Icons.lock_outline, color: _primaryColor, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _isNewPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: const Color(0xFF7D6C62),
                ),
                onPressed: () {
                  setState(() {
                    _isNewPasswordVisible = !_isNewPasswordVisible;
                  });
                },
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              hintText: 'Minimum 6 characters',
              hintStyle: const TextStyle(color: Color(0xFF9A8B82), fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Confirm Password Field
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5EFE9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5D7C9)),
          ),
          child: TextFormField(
            controller: _confirmPasswordController,
            obscureText: !_isConfirmPasswordVisible,
            style: const TextStyle(color: Color(0xFF2B1B12)),
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              labelStyle: const TextStyle(color: Color(0xFF7D6C62)),
              prefixIcon: Icon(Icons.lock_outline, color: _primaryColor, size: 20),
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
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Password Requirements
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7E9DF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Password Requirements:',
                style: TextStyle(
                  color: _primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              _buildRequirementText(
                'Minimum 6 characters',
                _newPasswordController.text.length >= 6,
              ),
              _buildRequirementText(
                'Password and confirmation match',
                _newPasswordController.text.isNotEmpty &&
                    _newPasswordController.text == _confirmPasswordController.text,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Reset Password Button
        _buildButton(
          text: 'Reset Password',
          color: _primaryColor,
          isLoading: _isLoading,
          onTap: _resetPassword,
        ),

        const SizedBox(height: 16),

        // Back to Login
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                '← Back to Login',
                style: TextStyle(
                  color: Color(0xFF7D6C62),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRequirementText(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 12,
            color: isMet ? _primaryColor : const Color(0xFF7D6C62),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: isMet ? const Color(0xFF2B1B12) : const Color(0xFF7D6C62),
            ),
          ),
        ],
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
                      // Header with back button
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

                      // Logo
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _primaryColor.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.lock_reset,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Step Indicator
                      _buildStepIndicator(),
                      const SizedBox(height: 32),

                      // ========== 3D FORM CARD ==========
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFC7B3A1), // 3D depth lip
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            const BoxShadow(
                              color: Color(0x332B1B12),
                              blurRadius: 8,
                              offset: Offset(0, 7),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.10),
                              blurRadius: 24,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.only(bottom: 7.0),
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
                              stops: [0.0, 0.40, 1.0],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFFE2D3C4),
                              width: 1.5,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: _currentStep == 1
                                ? _buildEnterEmailStep()
                                : _currentStep == 2
                                ? _buildEnterOtpStep()
                                : _buildResetPasswordStep(),
                          ),
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
}