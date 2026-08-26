// File: rider_helpsupport.dart
// Description: Help & Support page showing contact information

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RiderHelpSupport extends StatefulWidget {
  final bool isDarkMode;

  const RiderHelpSupport({
    super.key,
    required this.isDarkMode,
  });

  @override
  State<RiderHelpSupport> createState() => _RiderHelpSupportState();
}

class _RiderHelpSupportState extends State<RiderHelpSupport> {
  // Contact details
  final String supportPhoneNumber = "+91 90827 16947";
  final String supportEmail = "carrzzzcustomerhelp@gmail.com";

  void _copyToClipboard(String text, String type) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$type copied to clipboard!'),
        backgroundColor: const Color(0xFF3B82F6),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _makePhoneCall() {
    // Note: This will open the phone dialer on real devices
    // For emulator, it will show a dialog or just copy the number
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Call Support'),
        content: Text('Would you like to call $supportPhoneNumber?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // For real device, you can use: launchUrl(Uri.parse('tel:$supportPhoneNumber'));
              // For now, just copy the number
              _copyToClipboard(supportPhoneNumber, 'Phone number');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
            ),
            child: const Text('Call'),
          ),
        ],
      ),
    );
  }

  void _sendEmail() {
    // For real device, you can use: launchUrl(Uri.parse('mailto:$supportEmail'));
    // For now, just copy the email
    _copyToClipboard(supportEmail, 'Email address');
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111827) : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1F2937),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section with Icon
            Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.headset_mic,
                      size: 40,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'How can we help you?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We\'re here to assist you 24/7',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Contact Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Phone Number Card
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1F2937) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.phone,
                                color: Color(0xFF3B82F6),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Call Us',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                                    ),
                                  ),
                                  Text(
                                    'Available 24/7 for immediate assistance',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF111827) : Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  supportPhoneNumber,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF3B82F6),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _copyToClipboard(supportPhoneNumber, 'Phone number'),
                                icon: Icon(
                                  Icons.copy,
                                  size: 20,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                                tooltip: 'Copy number',
                              ),
                              IconButton(
                                onPressed: _makePhoneCall,
                                icon: const Icon(
                                  Icons.call,
                                  size: 20,
                                  color: Color(0xFF3B82F6),
                                ),
                                tooltip: 'Call now',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),


                  // FAQ Section (Optional)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1F2937) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.help_outline,
                                color: Color(0xFF3B82F6),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Quick FAQs',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                                    ),
                                  ),
                                  Text(
                                    'Common questions answered',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildFaqItem(
                          isDark: isDark,
                          question: 'How do I book a cat?',
                          answer: 'Select a car from the home screen, view details, and click "Rent Now" to proceed with booking.',
                        ),
                        const SizedBox(height: 12),
                        _buildFaqItem(
                          isDark: isDark,
                          question: 'What is the cancellation policy?',
                          answer: 'Free cancellation up to 24 hours before pickup. Cancellations within 24 hours may incur charges.',
                        ),
                        const SizedBox(height: 12),
                        _buildFaqItem(
                          isDark: isDark,
                          question: 'How do I upload documents?',
                          answer: 'Go to Profile > Personal Information to upload PAN card and Driving Licence.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem({
    required bool isDark,
    required String question,
    required String answer,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '• $question',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          answer,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            height: 1.4,
          ),
        ),
      ],
    );
  }
}