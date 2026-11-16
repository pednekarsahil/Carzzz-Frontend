// FILE: choice_screen.dart (UI redesign only - all backend logic unchanged)
// PURPOSE: Redesigned choice screen with modern UI while maintaining all backend functionality

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'rider_auth_screen.dart';
import 'partner_auth_screen.dart';
import '../widgets/app_icon_or_image.dart';

class ChoiceScreen extends StatefulWidget {
  const ChoiceScreen({super.key});

  @override
  State<ChoiceScreen> createState() => _ChoiceScreenState();
}

class _ChoiceScreenState extends State<ChoiceScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isRiderLoading = false;
  bool _isPartnerLoading = false;

  // Optional Header Logo (set image path e.g. 'assets/icon.png' to show logo above brand name)
  static const String? _headerLogoAsset = null;
  static const double _headerLogoSize = 70.0;
  static const double _headerLogoScale = 1.0;
  static const double _headerLogoOffsetX = 0.0; // Move Left (-) or Right (+)
  static const double _headerLogoOffsetY = 0.0; // Move Top (-) or Bottom (+)

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
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
    super.dispose();
  }

  // ⚠️ BACKEND LOGIC - UNCHANGED
  Future<void> _handleRiderSelection() async {
    setState(() {
      _isRiderLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    setState(() {
      _isRiderLoading = false;
    });

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RiderAuthScreen()),
    );
  }

  // ⚠️ BACKEND LOGIC - UNCHANGED
  Future<void> _handlePartnerSelection() async {
    setState(() {
      _isPartnerLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    setState(() {
      _isPartnerLoading = false;
    });

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PartnerAuthScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    children: [
                      // ========== REDESIGNED HEADER ==========
                      // Optional Header Logo
                      if (_headerLogoAsset != null && _headerLogoAsset!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AppIconOrImage(
                            imageAsset: _headerLogoAsset,
                            size: _headerLogoSize,
                            scale: _headerLogoScale,
                            offsetX: _headerLogoOffsetX,
                            offsetY: _headerLogoOffsetY,
                            fit: BoxFit.contain,
                          ),
                        ),
                      // Brand Name with Gradient
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF2B1B12), Color(0xFFFF5A1F)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: const Text(
                          'Carzzz',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      const Text(
                        'Premium Car Rental',
                        style: TextStyle(
                          fontSize: 18,
                          color: Color(0xFF7D6C62),
                          fontWeight: FontWeight.w400,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Container(
                        width: 60,
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF5A1F), Color(0xFFD98A5C)],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // ========== OPTIONS PAD (OUTER CARD AS SHOWN IN REFERENCE) ==========
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFC7B3A1), // 3D depth lip for outer pad
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            const BoxShadow(
                              color: Color(0x2E2B1B12),
                              blurRadius: 10,
                              offset: Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 22,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.only(bottom: 6.0), // 3D depth shelf
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFFFBF8F4), // Clean top light tone
                                Color(0xFFF1E9E0), // Subtle warm bottom tone
                              ],
                              stops: [0.0, 1.0],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: const Color(0xFFE2D3C4),
                              width: 1.5,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Driver Option - Modern Card Style
                              _buildModernOptionCard(
                                icon: Icons.drive_eta,
                                imageAsset: 'assets/drivewithuslogo.png',
                                // --- Separate Scale & Position Controls ---
                                imageSize: 120.0,      // Size of image/icon in pixels
                                imageScale: 2.2,     // Scale multiplier (e.g. 1.2 = 120%)
                                imageOffsetX: 0.0,   // Negative = Move Left, Positive = Move Right
                                imageOffsetY: -10.0,   // Negative = Move Up, Positive = Move Down
                                imagePadding: const EdgeInsets.all(4), // Inner padding
                                containerWidth: 56.0,  // Circular background width
                                containerHeight: 56.0, // Circular background height
                                // ------------------------------------------

                                title: 'Drive with Us',
                                subtitle: 'Book your dream car today',
                                features: const ['✓ Instant Booking', '✓ Best Prices'],
                                buttonText: 'Get Started',
                                buttonColor: const Color(0xFFFF5A1F),
                                isLoading: _isRiderLoading,
                                onTap: _handleRiderSelection,
                              ),

                              const SizedBox(height: 18),

                              // Partner Option - Modern Card Style
                              _buildModernOptionCard(
                                icon: Icons.business,
                                imageAsset: 'assets/partner.png', // Set image path (e.g. 'assets/...') to replace icon anytime
                                // --- Separate Scale & Position Controls ---
                                imageSize: 28.0,
                                imageScale: 2.0,
                                imageOffsetX: 0.0,   // Negative = Move Left, Positive = Move Right
                                imageOffsetY: 0.0,   // Negative = Move Up, Positive = Move Down
                                imagePadding: const EdgeInsets.all(6),
                                containerWidth: 56.0,
                                containerHeight: 56.0,
                                // ------------------------------------------

                                title: 'Partner Program',
                                subtitle: 'Join our network of car owners',
                                features: const ['✓ Earn Passive Income', '✓ Full Support'],
                                buttonText: 'Become Partner',
                                buttonColor: const Color(0xFFFF5A1F),
                                isLoading: _isPartnerLoading,
                                onTap: _handlePartnerSelection,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // ========== REDESIGNED FOOTER ==========


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

  // ========== NEW MODERN OPTION CARD (NOTCHED CORNER DESIGN) ==========
  Widget _buildModernOptionCard({
    required IconData icon,
    String? imageAsset,
    double? imageSize,
    double? imageScale,
    double? imageOffsetX,
    double? imageOffsetY,
    EdgeInsetsGeometry? imagePadding,
    double? containerWidth,
    double? containerHeight,
    double? notchWidth,
    double? notchHeight,

    required String title,
    required String subtitle,
    required List<String> features,
    required String buttonText,
    required Color buttonColor,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    final double actualNotchWidth =
        notchWidth ?? (buttonText.length > 12 ? 188.0 : 158.0);
    final double actualNotchHeight = notchHeight ?? 56.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Notched Card Body with CustomPainter
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: CustomPaint(
            painter: _NotchedCardPainter(
              notchWidth: actualNotchWidth,
              notchHeight: actualNotchHeight,
              backgroundColor: const Color(0xFFFAF7F4),
              borderColor: const Color(0xFFE6D7CA),
              borderWidth: 1.5,
            ),
            child: Padding(
              padding: const EdgeInsets.only(
                left: 20.0,
                top: 20.0,
                right: 20.0,
                bottom: 12.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon and Title Row
                  Row(
                    children: [
                      SizedBox(
                        width: containerWidth ?? 56,
                        height: containerHeight ?? 56,
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Pure silhouette drop shadow behind the logo (no circular container)
                              Transform.translate(
                                offset: const Offset(0, 4),
                                child: ImageFiltered(
                                  imageFilter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                                  child: ColorFiltered(
                                    colorFilter: ColorFilter.mode(
                                      Colors.black.withOpacity(0.30),
                                      BlendMode.srcIn,
                                    ),
                                    child: AppIconOrImage(
                                      icon: icon,
                                      imageAsset: imageAsset,
                                      size: imageSize ?? 42,
                                      scale: imageScale ?? 1.0,
                                      offsetX: imageOffsetX ?? 0.0,
                                      offsetY: imageOffsetY ?? 0.0,
                                      fit: BoxFit.contain,
                                      padding: imagePadding ?? EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ),
                              // Foreground crisp logo
                              AppIconOrImage(
                                icon: icon,
                                imageAsset: imageAsset,
                                size: imageSize ?? 42,
                                scale: imageScale ?? 1.0,
                                offsetX: imageOffsetX ?? 0.0,
                                offsetY: imageOffsetY ?? 0.0,
                                fit: BoxFit.contain,
                                padding: imagePadding ?? EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2B1B12),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF7D6C62),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // Features on the left, notch placeholder on the right
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: features.map((feature) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Text(
                                feature,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF4A382E),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      SizedBox(
                        width: actualNotchWidth - 20.0,
                        height: actualNotchHeight - 12.0,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Action Button docked in the bottom-right notch cutout
        Positioned(
          right: 0,
          bottom: 0,
          width: actualNotchWidth,
          height: actualNotchHeight,
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(buttonColor),
                    ),
                  )
                : _ThreeDPushButton(
                    text: buttonText,
                    baseColor: buttonColor,
                    onTap: onTap,
                  ),
          ),
        ),
      ],
    );
  }
}

// ========== CUSTOM PAINTER FOR 3D NOTCHED CARD SHAPE ==========
class _NotchedCardPainter extends CustomPainter {
  final double notchWidth;
  final double notchHeight;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  static const double depth = 5.0;

  const _NotchedCardPainter({
    required this.notchWidth,
    required this.notchHeight,
    required this.backgroundColor,
    required this.borderColor,
    this.borderWidth = 1.5,
  });

  Path _getNotchedPath(Size size) {
    final path = Path();
    final double w = size.width;
    final double h = size.height;
    const double rOuter = 20.0;
    const double rNotch = 14.0;

    final double nw = notchWidth.clamp(60.0, w - rOuter * 2);
    final double nh = notchHeight.clamp(30.0, h - rOuter * 2);

    // 1. Top-left corner to top-right corner
    path.moveTo(rOuter, 0);
    path.lineTo(w - rOuter, 0);
    path.arcToPoint(
      Offset(w, rOuter),
      radius: const Radius.circular(rOuter),
    );

    // 2. Right edge down to notch
    path.lineTo(w, h - nh - rNotch);
    path.arcToPoint(
      Offset(w - rNotch, h - nh),
      radius: const Radius.circular(rNotch),
    );

    // 3. Horizontal edge inward (to the left)
    path.lineTo(w - nw + rNotch, h - nh);
    path.arcToPoint(
      Offset(w - nw, h - nh + rNotch),
      radius: const Radius.circular(rNotch),
      clockwise: false, // Concave inside corner
    );

    // 4. Vertical edge down to bottom edge
    path.lineTo(w - nw, h - rOuter);
    path.arcToPoint(
      Offset(w - nw - rOuter, h),
      radius: const Radius.circular(rOuter),
    );

    // 5. Bottom edge to bottom-left corner
    path.lineTo(rOuter, h);
    path.arcToPoint(
      Offset(0, h - rOuter),
      radius: const Radius.circular(rOuter),
    );

    // 6. Left edge up to top-left corner
    path.lineTo(0, rOuter);
    path.arcToPoint(
      Offset(rOuter, 0),
      radius: const Radius.circular(rOuter),
    );

    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double faceHeight = size.height - depth;
    final topPath = _getNotchedPath(Size(size.width, faceHeight));
    final depthPath = topPath.shift(Offset(0, depth));

    // 1. Layered 3D drop shadows under the bottom depth extrusion
    final ambientShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawPath(depthPath.shift(const Offset(0, 5)), ambientShadowPaint);

    final contactShadowPaint = Paint()
      ..color = const Color(0x1F2B1B12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(depthPath.shift(const Offset(0, 2)), contactShadowPaint);

    // 2. 3D Depth Extrusion (solid beveled edge between top face and bottom rim)
    for (double dy = depth; dy >= 1.0; dy -= 1.0) {
      canvas.drawPath(
        topPath.shift(Offset(0, dy)),
        Paint()
          ..color = const Color(0xFFD6C5B5)
          ..style = PaintingStyle.fill,
      );
    }

    // Depth lip bottom border accent
    final depthBorderPaint = Paint()
      ..color = const Color(0xFFBAA897)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(depthPath, depthBorderPaint);

    // 3. Top Face Gradient Fill (volumetric 3D lighting reflection)
    final Rect faceRect = Rect.fromLTWH(0, 0, size.width, faceHeight);
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFFFFF), // Crisp top light reflection
          Color(0xFFFAF7F4), // Main face body
          Color(0xFFF3ECE4), // Subtle bottom ambient shadow
        ],
        stops: [0.0, 0.45, 1.0],
      ).createShader(faceRect)
      ..style = PaintingStyle.fill;
    canvas.drawPath(topPath, fillPaint);

    // 4. Top Face Outer Bevel Border
    final strokePaint = Paint()
      ..color = const Color(0xFFE2D3C4)
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;
    canvas.drawPath(topPath, strokePaint);

    // 5. Specular highlight line along top rim
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.65)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(topPath.shift(const Offset(0, 1)), highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _NotchedCardPainter oldDelegate) {
    return oldDelegate.notchWidth != notchWidth ||
        oldDelegate.notchHeight != notchHeight ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth;
  }
}

class _ThreeDPushButton extends StatefulWidget {
  final String text;
  final Color baseColor;
  final VoidCallback? onTap;

  const _ThreeDPushButton({
    required this.text,
    required this.baseColor,
    required this.onTap,
  });

  @override
  State<_ThreeDPushButton> createState() => _ThreeDPushButtonState();
}

class _ThreeDPushButtonState extends State<_ThreeDPushButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final HSLColor hsl = HSLColor.fromColor(widget.baseColor);
    final Color highlightColor =
        hsl.withLightness((hsl.lightness + 0.12).clamp(0.0, 1.0)).toColor();
    final Color midColor = widget.baseColor;
    final Color lowerFaceColor =
        hsl.withLightness((hsl.lightness - 0.05).clamp(0.0, 1.0)).toColor();
    final Color depthLipColor =
        hsl.withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0)).toColor();

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        margin: EdgeInsets.only(top: _isPressed ? 3.5 : 0.0),
        padding: EdgeInsets.only(bottom: _isPressed ? 1.5 : 5.0),
        decoration: BoxDecoration(
          color: depthLipColor,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: depthLipColor.withOpacity(_isPressed ? 0.25 : 0.42),
              blurRadius: _isPressed ? 4 : 10,
              offset: Offset(0, _isPressed ? 2 : 5),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [highlightColor, midColor, lowerFaceColor],
              stops: const [0.0, 0.45, 1.0],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withOpacity(0.32),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  shadows: [
                    Shadow(
                      color: Color(0x554A1400),
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward,
                color: Colors.white,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}