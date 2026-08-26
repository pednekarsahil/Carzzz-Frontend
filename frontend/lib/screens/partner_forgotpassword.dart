// FILE: partner_forgotpassword.dart
// PURPOSE: Partner forgot password screen with email verification and OTP functionality
// UI: Matches the same design as partner_auth_screen.dart

import 'package:flutter/material.dart';

class PartnerForgotPasswordScreen extends StatefulWidget {
  const PartnerForgotPasswordScreen({super.key});

  @override
  State<PartnerForgotPasswordScreen> createState() => _PartnerForgotPasswordScreenState();
}

class _PartnerForgotPasswordScreenState extends State<PartnerForgotPasswordScreen>
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
        duration: const Duration(seconds: 2),
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
      _showSnackBar('Please enter your business email', const Color(0xFFEF4444));
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
      // Simulate API call to send OTP
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      _showSnackBar('OTP sent to ${_emailController.text}', const Color(0xFF10B981));
      setState(() {
        _currentStep = 2;
      });
      _startResendTimer();
    } catch (e) {
      _showSnackBar('Failed to send OTP. Please try again.', const Color(0xFFEF4444));
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
      // Simulate API call to verify OTP
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      // For demo purposes, accept any 6-digit OTP
      _showSnackBar('OTP verified successfully!', const Color(0xFF10B981));
      setState(() {
        _currentStep = 3;
      });
    } catch (e) {
      _showSnackBar('Invalid OTP. Please try again.', const Color(0xFFEF4444));
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
      // Simulate API call to reset password
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      _showSnackBar('Password reset successful! Please login with your new password.', const Color(0xFF10B981));

      // Navigate back to login screen
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    } catch (e) {
      _showSnackBar('Failed to reset password. Please try again.', const Color(0xFFEF4444));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _resendOtp() {
    if (!_canResendOtp) return;

    setState(() {
      _isResendingOtp = true;
    });

    // Simulate resending OTP
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _showSnackBar('New OTP sent to ${_emailController.text}', const Color(0xFF10B981));
        setState(() {
          _isResendingOtp = false;
        });
        _startResendTimer();
      }
    });
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
          color: _currentStep >= 2 ? const Color(0xFF10B981) : Colors.grey[300],
        ),
        _buildStepCircle(2, 'OTP'),
        Container(
          width: 40,
          height: 2,
          color: _currentStep >= 3 ? const Color(0xFF10B981) : Colors.grey[300],
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
            color: isActive ? const Color(0xFF10B981) : Colors.grey[300],
            border: isActive ? null : Border.all(color: Colors.grey[400]!),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
              step.toString(),
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey[600],
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
            color: isActive ? const Color(0xFF10B981) : Colors.grey[500],
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
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter your business email address and we\'ll send you a verification code to reset your password.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),

        // Email Field
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Color(0xFF1F2937)),
            decoration: const InputDecoration(
              labelText: 'Business Email',
              labelStyle: TextStyle(color: Color(0xFF6B7280)),
              prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF10B981), size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              hintText: 'partner@yourbusiness.com',
              hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Send OTP Button
        _buildButton(
          text: 'Send Verification Code',
          color: const Color(0xFF10B981),
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
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Back to Login',
                style: TextStyle(
                  color: Color(0xFF10B981),
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
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'We\'ve sent a 6-digit verification code to',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
        Text(
          _emailController.text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF10B981),
          ),
        ),
        const SizedBox(height: 24),

        // OTP Field
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: const TextStyle(color: Color(0xFF1F2937), fontSize: 18, letterSpacing: 2),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              labelText: 'Verification Code',
              labelStyle: TextStyle(color: Color(0xFF6B7280)),
              prefixIcon: Icon(Icons.security, color: Color(0xFF10B981), size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
            _canResendOtp
                ? TextButton(
              onPressed: _resendOtp,
              child: _isResendingOtp
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                ),
              )
                  : const Text(
                'Resend',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
                : Text(
              'Resend in $_resendTimer sec',
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Verify OTP Button
        _buildButton(
          text: 'Verify OTP',
          color: const Color(0xFF10B981),
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
                });
              },
              child: const Text(
                '← Back to Email',
                style: TextStyle(
                  color: Color(0xFF6B7280),
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
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your new password must be different from previously used passwords.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),

        // New Password Field
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: TextFormField(
            controller: _newPasswordController,
            obscureText: !_isNewPasswordVisible,
            style: const TextStyle(color: Color(0xFF1F2937)),
            decoration: InputDecoration(
              labelText: 'New Password',
              labelStyle: const TextStyle(color: Color(0xFF6B7280)),
              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF10B981), size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _isNewPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: const Color(0xFF6B7280),
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
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Confirm Password Field
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: TextFormField(
            controller: _confirmPasswordController,
            obscureText: !_isConfirmPasswordVisible,
            style: const TextStyle(color: Color(0xFF1F2937)),
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              labelStyle: const TextStyle(color: Color(0xFF6B7280)),
              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF10B981), size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: const Color(0xFF6B7280),
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
            color: const Color(0xFFFEF3C7).withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Password Requirements:',
                style: TextStyle(
                  color: Color(0xFF92400E),
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
          color: const Color(0xFF10B981),
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
                  color: Color(0xFF6B7280),
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
            color: isMet ? const Color(0xFF10B981) : const Color(0xFF92400E),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: isMet ? const Color(0xFF065F46) : const Color(0xFF92400E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required Color color,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE0F2FE),
              Color(0xFFF0FDF4),
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
                    children: [
                      // Header with back button
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
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
                                color: Color(0xFF10B981),
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
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.3),
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

                      // Form Container
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 32,
                              offset: const Offset(0, 8),
                            ),
                          ],
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