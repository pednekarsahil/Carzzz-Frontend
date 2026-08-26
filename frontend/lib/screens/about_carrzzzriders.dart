// File: about_carrzzzriders.dart
// Description: About page for carrzz - car rental service information

import 'package:flutter/material.dart';

class AboutcarrzzRiders extends StatefulWidget {
  final bool isDarkMode;

  const AboutcarrzzRiders({
    super.key,
    required this.isDarkMode,
  });

  @override
  State<AboutcarrzzRiders> createState() => _AboutcarrzzRidersState();
}

class _AboutcarrzzRidersState extends State<AboutcarrzzRiders> {
  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111827) : Colors.grey[50],
      appBar: AppBar(
        title: const Text('About Carzzz'),
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
            // Hero Section with Logo


            // Main Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Our Story Section
                  _buildSection(
                    isDark: isDark,
                    title: 'Our Story',
                    icon: Icons.history,
                    content: 'carrzz was founded with a simple vision - to make car rentals accessible, affordable, and hassle-free for everyone. We believe that the freedom of riding shouldn\'t come with complicated processes and hidden costs. Whether you\'re a daily commuter, a weekend explorer, or someone looking to try a different car, carrzz is here to make your journey smooth and enjoyable.',
                  ),

                  const SizedBox(height: 24),

                  // How to Rent a Car Section
                  _buildSection(
                    isDark: isDark,
                    title: 'How to Rent a Car',
                    icon: Icons.motorcycle,
                    content: '',
                    isListSection: true,
                    listItems: [
                      '📱 Browse & Select - Choose from a wide range of Cars near your location',
                      '📄 Upload Documents - Quick verification with PAN card & Driving Licence',
                      '💰 Review Price Breakup - Check rental price, platform fee, and available offers',
                      '🎯 Apply Discount Offers - Get up to 50% off on selected Cars',
                      '✅ Confirm Booking - Complete the booking process in just a few taps',
                      '🔑 Pick Up & Ride - Collect your Cars from the designated location',
                      '🏍️ Enjoy Your Ride - Explore the city on your favorite Cars',
                      '📸 Return & Pay - Return the Cars and complete payment seamlessly',
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Why Choose Us Section
                  _buildSection(
                    isDark: isDark,
                    title: 'Why Choose Carzz?',
                    icon: Icons.emoji_events,
                    content: '',
                    isGridSection: true,
                  ),

                  const SizedBox(height: 16),

                  // Features Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      _buildFeatureCard(
                        isDark: isDark,
                        icon: Icons.verified,
                        title: 'Verified Cars',
                        description: 'All Cars are well-maintained and verified',
                      ),
                      _buildFeatureCard(
                        isDark: isDark,
                        icon: Icons.attach_money,
                        title: 'Best Prices',
                        description: 'Competitive rates with amazing offers',
                      ),
                      _buildFeatureCard(
                        isDark: isDark,
                        icon: Icons.support_agent,
                        title: '24/7 Support',
                        description: 'Round-the-clock customer assistance',
                      ),
                      _buildFeatureCard(
                        isDark: isDark,
                        icon: Icons.security,
                        title: 'Safe & Secure',
                        description: 'Secure payments and insured rides',
                      ),
                      _buildFeatureCard(
                        isDark: isDark,
                        icon: Icons.speed,
                        title: 'Quick Booking',
                        description: 'Book a Car in just a few minutes',
                      ),
                      _buildFeatureCard(
                        isDark: isDark,
                        icon: Icons.room,
                        title: 'Multiple Locations',
                        description: 'Find Cars near your location',
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Rental Pricing Card
                  Container(
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
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.currency_rupee,
                                color: Color(0xFF3B82F6),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Rental Pricing',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '• Daily rentals starting from just ₹149/day\n'
                              '• Platform fee of ₹50 per booking\n'
                              '• Discount offers up to 50% on selected Cars\n'
                              '• No hidden charges - transparent pricing\n'
                              '• Free cancellation up to 24 hours before pickup\n'
                              '• Security deposit (refundable) as per Car category',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Requirements Card
                  Container(
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
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.assignment,
                                color: Color(0xFF3B82F6),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Requirements',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '• Valid Driving Licence (Mandatory)\n'
                              '• PAN Card for verification\n'
                              '• Age: 18+ years\n'
                              '• Government-issued ID proof for address verification\n'
                              '• Valid mobile number and email address',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Mission & Vision
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
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
                            children: [
                              const Icon(
                                Icons.rocket_launch,
                                size: 32,
                                color: Color(0xFF3B82F6),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Our Mission',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'To provide affordable, reliable, and hassle-free car rentals for every rider, enabling freedom of movement across the city.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
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
                            children: [
                              const Icon(
                                Icons.visibility,
                                size: 32,
                                color: Color(0xFF3B82F6),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Our Vision',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'To become the most trusted and preferred Car rental platform, empowering millions to explore their cities on two wheels.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Footer
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          'Ride Safe, Ride Free with Carzzz',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '© 2026 Carzz. All rights reserved.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[500] : Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required bool isDark,
    required String title,
    required IconData icon,
    required String content,
    bool isListSection = false,
    List<String>? listItems,
    bool isGridSection = false,
  }) {
    return Container(
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF3B82F6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (content.isNotEmpty)
            Text(
              content,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          if (isListSection && listItems != null)
            ...listItems.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                item,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required bool isDark,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: const Color(0xFF3B82F6),
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}