// FILE: rider_pricebreakup.dart
// COMPLETE UPDATED CODE - Added professional success animation
// UPDATED: Payment success now shows congratulatory message with animations
// FIXED: Scrolling issue - Pay Now button now accessible by sliding down
// FIXED: API endpoint for order creation
// FIXED: Release hold endpoint

import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class RiderPriceBreakup extends StatefulWidget {
  final Map<String, dynamic> carData;
  final Map<String, dynamic> userData;
  final bool isDarkMode;

  const RiderPriceBreakup({
    super.key,
    required this.carData,
    required this.userData,
    required this.isDarkMode,
  });

  @override
  State<RiderPriceBreakup> createState() => _RiderPriceBreakupState();
}

class _RiderPriceBreakupState extends State<RiderPriceBreakup> {
  // Variables to store price details
  double vehiclePrice = 0;
  double platformFee = 10;
  double discountPercentage = 0;
  double totalPrice = 0;
  double discountedVehiclePrice = 0;

  // Date and time variables
  DateTime? selectedStartDate;
  TimeOfDay? selectedStartTime;
  DateTime? selectedEndDate;
  TimeOfDay? selectedEndTime;
  String rentalDuration = ''; // "hourly", "halfday", "custom"
  int selectedHours = 1;
  double originalHourlyPrice = 0;
  double originalHalfDayPrice = 0;
  double originalFullDayPrice = 0;

  int? selectedOfferIndex;
  bool isPartnerOfferApplied = false;

  // car photos variables
  List<File> carPhotos = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool iscarConditionFine = false;

  late Razorpay _razorpay;
  static const String _razorpayKey = 'rzp_test_ScRentKEtlnMIH';

  static const bool _usePhysicalDevice = false;

  String get _baseUrl {
    if (_usePhysicalDevice) {
      return 'http://10.0.2.2:3000';
    } else {
      return 'https://carzzz-frontend.onrender.com';
    }
  }

  final List<Map<String, dynamic>> offers = [
    {'percentage': 10, 'label': '10% OFF', 'color': const Color(0xFF10B981)},
    {'percentage': 20, 'label': '20% OFF', 'color': const Color(0xFF3B82F6)},
    {'percentage': 50, 'label': '50% OFF', 'color': const Color(0xFFEF4444)},
  ];

  @override
  void initState() {
    super.initState();

    originalFullDayPrice = (widget.carData['price'] as num).toDouble();
    originalHalfDayPrice = widget.carData['halfDayPrice'] != null
        ? (widget.carData['halfDayPrice'] as num).toDouble()
        : originalFullDayPrice * 0.6;
    originalHourlyPrice = widget.carData['hourlyPrice'] != null
        ? (widget.carData['hourlyPrice'] as num).toDouble()
        : originalFullDayPrice / 8;

    vehiclePrice = originalFullDayPrice;

    // Initialize with current time
    final now = DateTime.now();
    selectedStartDate = now;
    selectedStartTime = TimeOfDay.fromDateTime(now);
    final oneHourLater = now.add(const Duration(hours: 1));
    selectedEndDate = oneHourLater;
    selectedEndTime = TimeOfDay.fromDateTime(oneHourLater);

    _calculateTotalPrice();

    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _calculateTotalPrice() {
    setState(() {
      discountedVehiclePrice = vehiclePrice - (vehiclePrice * discountPercentage / 100);
      double subtotal = discountedVehiclePrice + platformFee;
      totalPrice = subtotal;
      if (totalPrice < 0) totalPrice = 0;
    });
  }

  void _calculateRentalPrice() {
    setState(() {
      if (rentalDuration == 'hourly') {
        if (selectedHours >= 1 && selectedHours <= 8) {
          vehiclePrice = originalHourlyPrice * selectedHours;
        } else {
          vehiclePrice = originalHourlyPrice;
        }
      } else if (rentalDuration == 'halfday') {
        vehiclePrice = originalHalfDayPrice;
      } else if (rentalDuration == 'custom' && selectedStartDate != null && selectedEndDate != null) {
        DateTime startDateTime = DateTime(
          selectedStartDate!.year,
          selectedStartDate!.month,
          selectedStartDate!.day,
          selectedStartTime?.hour ?? 0,
          selectedStartTime?.minute ?? 0,
        );
        DateTime endDateTime = DateTime(
          selectedEndDate!.year,
          selectedEndDate!.month,
          selectedEndDate!.day,
          selectedEndTime?.hour ?? 0,
          selectedEndTime?.minute ?? 0,
        );
        Duration difference = endDateTime.difference(startDateTime);
        int totalHours = difference.inHours;

        if (totalHours <= 0) {
          vehiclePrice = originalHourlyPrice;
        } else if (totalHours <= 8) {
          vehiclePrice = originalHourlyPrice * totalHours;
        } else if (totalHours <= 12) {
          vehiclePrice = originalHalfDayPrice;
        } else {
          int days = (totalHours / 24).ceil();
          vehiclePrice = originalFullDayPrice * days;
        }
      }
      _calculateTotalPrice();
    });
  }

  // Helper method to get start datetime - FOR HOURLY/HALFDAY RETURNS CURRENT TIME
  DateTime _getStartDateTimeForBooking() {
    // For hourly and halfday, always use current time
    if (rentalDuration == 'hourly' || rentalDuration == 'halfday') {
      return DateTime.now();
    }

    // For custom, use selected date and time
    if (selectedStartDate != null && selectedStartTime != null) {
      return DateTime(
        selectedStartDate!.year,
        selectedStartDate!.month,
        selectedStartDate!.day,
        selectedStartTime!.hour,
        selectedStartTime!.minute,
      );
    }
    return DateTime.now();
  }

  // Helper method to get end datetime based on rental type
  DateTime _getEndDateTimeForBooking() {
    final now = DateTime.now();

    // For hourly: current time + selected hours
    if (rentalDuration == 'hourly') {
      return now.add(Duration(hours: selectedHours));
    }

    // For halfday: current time + 12 hours
    if (rentalDuration == 'halfday') {
      return now.add(const Duration(hours: 12));
    }

    // For custom: use selected end date and time
    if (selectedEndDate != null && selectedEndTime != null) {
      return DateTime(
        selectedEndDate!.year,
        selectedEndDate!.month,
        selectedEndDate!.day,
        selectedEndTime!.hour,
        selectedEndTime!.minute,
      );
    }
    return now.add(const Duration(days: 1));
  }

  DateTime _getStartDateTime() {
    if (selectedStartDate != null && selectedStartTime != null) {
      return DateTime(
        selectedStartDate!.year,
        selectedStartDate!.month,
        selectedStartDate!.day,
        selectedStartTime!.hour,
        selectedStartTime!.minute,
      );
    }
    return DateTime.now();
  }

  DateTime _getEndDateTime() {
    if (selectedEndDate != null && selectedEndTime != null) {
      return DateTime(
        selectedEndDate!.year,
        selectedEndDate!.month,
        selectedEndDate!.day,
        selectedEndTime!.hour,
        selectedEndTime!.minute,
      );
    }
    return DateTime.now().add(const Duration(days: 1));
  }

  // car photos methods
  Future<void> _pickcarPhoto() async {
    if (carPhotos.length >= 10) {
      _showErrorDialog('You can only upload up to 10 photos');
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                final XFile? photo = await _imagePicker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 80,
                );
                if (photo != null) {
                  setState(() {
                    carPhotos.add(File(photo.path));
                  });
                }
              },
              child: ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a photo'),
              ),
            ),
            GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                final XFile? photo = await _imagePicker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 80,
                );
                if (photo != null) {
                  setState(() {
                    carPhotos.add(File(photo.path));
                  });
                }
              },
              child: ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from gallery'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _removecarPhoto(int index) {
    setState(() {
      carPhotos.removeAt(index);
    });
  }

  // Date picker with validation
  Future<void> _selectStartDate(BuildContext context) async {
    final now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedStartDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3B82F6),
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedStartDate = picked;
        if (selectedEndDate != null && selectedEndDate!.isBefore(picked)) {
          selectedEndDate = picked.add(const Duration(hours: 1));
        }
        _calculateRentalPrice();
      });
    }
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedStartTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3B82F6),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedStartTime = picked;
        _calculateRentalPrice();
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedEndDate ?? (selectedStartDate ?? DateTime.now()).add(const Duration(days: 1)),
      firstDate: selectedStartDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3B82F6),
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedEndDate = picked;
        _calculateRentalPrice();
      });
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedEndTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3B82F6),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedEndTime = picked;
        _calculateRentalPrice();
      });
    }
  }

  void _selectRentalDuration(String duration) {
    setState(() {
      rentalDuration = duration;
      _calculateRentalPrice();
    });
  }

  void _applyOffer(int index, double percentage) {
    setState(() {
      if (selectedOfferIndex == index && !isPartnerOfferApplied) {
        selectedOfferIndex = null;
        discountPercentage = 0;
      } else {
        selectedOfferIndex = index;
        isPartnerOfferApplied = false;
        discountPercentage = percentage;
      }
      _calculateTotalPrice();
    });
  }

  void _applyPartnerOffer(double percentage) {
    setState(() {
      if (isPartnerOfferApplied) {
        isPartnerOfferApplied = false;
        discountPercentage = 0;
        selectedOfferIndex = null;
      } else {
        isPartnerOfferApplied = true;
        selectedOfferIndex = null;
        discountPercentage = percentage;
      }
      _calculateTotalPrice();
    });
  }

  // UPDATED: Professional success screen with animations
  Future<void> _showSuccessScreen() async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => SuccessScreen(
          carName: widget.carData['name'],
          totalAmount: totalPrice,
          rentalDuration: rentalDuration,
          isDarkMode: false,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
    // After success screen, return to dashboard
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    // Validate Car condition before proceeding
    if (!iscarConditionFine) {
      _showErrorDialog('Please confirm that the car condition is fine before proceeding.');
      return;
    }

    if (carPhotos.isEmpty) {
      _showErrorDialog('Please upload at least one photo of the car before proceeding.');
      return;
    }

    print('Payment Successful: ${response.paymentId}');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF3B82F6)),
              SizedBox(height: 16),
              Text(
                'Confirming your booking...',
                style: TextStyle(
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        if (mounted) Navigator.pop(context);
        _showErrorDialog('Authentication error. Please login again.');
        return;
      }

      // Get start and end times based on rental type
      DateTime startDateTime = _getStartDateTimeForBooking();
      DateTime endDateTime = _getEndDateTimeForBooking();

      // SKIP past date validation for hourly and halfday since they use current time
      if (rentalDuration == 'custom') {
        // Only validate for custom rental
        if (startDateTime.isBefore(DateTime.now())) {
          if (mounted) Navigator.pop(context);
          _showErrorDialog('Start date and time cannot be in the past. Please select a future date/time.');
          return;
        }

        if (startDateTime.isAfter(endDateTime) || startDateTime.isAtSameMomentAs(endDateTime)) {
          if (mounted) Navigator.pop(context);
          _showErrorDialog('End time must be after start time.');
          return;
        }
      } else {
        // For hourly/halfday, just ensure end time is after start time
        if (endDateTime.isBefore(startDateTime) || endDateTime.isAtSameMomentAs(startDateTime)) {
          if (mounted) Navigator.pop(context);
          _showErrorDialog('Invalid rental duration. Please try again.');
          return;
        }

        // For hourly/halfday, add a small buffer (1 second) to ensure start time is not considered "past"
        // This prevents server-side validation errors due to millisecond differences
        if (rentalDuration == 'hourly' || rentalDuration == 'halfday') {
          // Ensure startDateTime has no milliseconds to avoid precision issues
          startDateTime = DateTime(
            startDateTime.year,
            startDateTime.month,
            startDateTime.day,
            startDateTime.hour,
            startDateTime.minute,
            startDateTime.second,
          );
        }
      }

      // ========== FIXED: Correct API endpoint ==========
      final orderResponse = await http.post(
        Uri.parse('$_baseUrl/api/create-order'),  // ← FIXED: Added /api prefix
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'carId': widget.carData['id'],
          'carModel': widget.carData['name'],
          'amount': totalPrice.toInt(),
          'originalPrice': vehiclePrice.toInt(),
          'discountPercentage': discountPercentage,
          'platformFee': platformFee.toInt(),
          'paymentId': response.paymentId,
          'razorpayOrderId': response.orderId,
          'rentalType': rentalDuration.isNotEmpty ? rentalDuration : 'fullday',
          'startDateTime': startDateTime.toIso8601String(),
          'endDateTime': endDateTime.toIso8601String(),
          'rentalHours': rentalDuration == 'hourly' ? selectedHours : (rentalDuration == 'halfday' ? 12 : null),
          'calculatedPrice': vehiclePrice,
          'hourlyRate': originalHourlyPrice,
          'halfDayRate': originalHalfDayPrice,
          'dailyRate': originalFullDayPrice,
          'skipPastDateValidation': rentalDuration == 'hourly' || rentalDuration == 'halfday',
          'carPhotos': carPhotos.map((photo) => photo.path).toList(),
          'carConditionConfirmed': iscarConditionFine,
        }),
      );

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (orderResponse.statusCode == 200 || orderResponse.statusCode == 201) {
        final orderData = json.decode(orderResponse.body);
        if (orderData['success'] == true) {
          // ========== FIXED: Release hold using the hold endpoint ==========
          try {
            await http.delete(
              Uri.parse('$_baseUrl/api/cars/hold/${widget.carData['id']}'),  // Changed from release-reservation to hold
              headers: {'Authorization': 'Bearer $token'},
            );
          } catch (e) {
            print('Error releasing hold: $e');
          }

          if (mounted) {
            // Show professional success screen
            await _showSuccessScreen();
          }
        } else {
          _showErrorDialog(orderData['message'] ?? 'Failed to confirm booking. Please contact support.');
        }
      } else {
        final errorData = json.decode(orderResponse.body);
        _showErrorDialog(errorData['message'] ?? 'Payment successful but booking confirmation failed. Please contact support.');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      print('Error confirming booking: $e');
      _showErrorDialog('Payment successful but booking confirmation failed. Please contact support.');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFFFAF7F4),
        title: const Text(
          'Booking Failed',
          style: TextStyle(
            color: Color(0xFF2B1B12),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: Color(0xFF7D6C62),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(
                color: Color(0xFFFF5A1F),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _initiatePayment() {
    // Skip validation for hourly/halfday as they use current time
    if (rentalDuration == 'custom') {
      DateTime startDateTime = _getStartDateTime();
      if (startDateTime.isBefore(DateTime.now())) {
        _showErrorDialog('Start date and time cannot be in the past. Please select a future date/time.');
        return;
      }
    }

    // Validate car condition before payment
    if (!iscarConditionFine) {
      _showErrorDialog('Please confirm that the car condition is fine before proceeding with payment.');
      return;
    }

    if (carPhotos.isEmpty) {
      _showErrorDialog('Please upload at least one photo of the car before proceeding with payment.');
      return;
    }

    var options = {
      'key': _razorpayKey,
      'amount': (totalPrice * 100).toInt(),
      'name': 'carrzz',
      'description': 'Rental Payment for ${widget.carData['name']}',
      'prefill': {
        'contact': widget.userData['phone'] ?? '9876543210',
        'email': widget.userData['email'] ?? 'user@example.com',
        'name': widget.userData['fullname'] ?? 'Rider',
      },
      'theme': {
        'color': '#FF5A1F',
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      print('Error opening Razorpay: $e');
      _showErrorDialog('Could not open payment gateway. Please try again.');
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print('Payment Error: ${response.code} - ${response.message}');
    _showErrorDialog('Payment failed. Please try again.');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print('External Wallet: ${response.walletName}');
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bool isDark = false;

    return Scaffold(
      backgroundColor: const Color(0xFFEDE1D5),
      appBar: AppBar(
        title: const Text('Price Breakup', style: TextStyle(color: Color(0xFF2B1B12), fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFAF7F4),
        foregroundColor: const Color(0xFF2B1B12),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2B1B12)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFEDE1D5),
        child: Column(
        children: [
          // Main scrollable content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                children: [
                  // car Information Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F4),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7E9DF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.directions_car,
                            color: Color(0xFFFF5A1F),
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.carData['name'],
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2B1B12),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.carData['type']} • ${widget.carData['distance']} away',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF7D6C62),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.star, size: 14, color: Color(0xFFFF5A1F)),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.carData['rating'].toString(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2B1B12),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.access_time, size: 12, color: Color(0xFF7D6C62)),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Flexible Rental',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF7D6C62),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Rental Duration Selection Section
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Rental Duration',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2B1B12),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7F4),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              // Quick Duration Options
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDurationOption(
                                      'Hourly',
                                      Icons.access_time,
                                      rentalDuration == 'hourly',
                                      isDark,
                                          () => _selectRentalDuration('hourly'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildDurationOption(
                                      'Half Day',
                                      Icons.wb_sunny,
                                      rentalDuration == 'halfday',
                                      isDark,
                                          () => _selectRentalDuration('halfday'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildDurationOption(
                                      'Custom',
                                      Icons.calendar_today,
                                      rentalDuration == 'custom',
                                      isDark,
                                          () => _selectRentalDuration('custom'),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Hourly selector
                              if (rentalDuration == 'hourly')
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5EFE9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Select Hours (1-8 hours)',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF2B1B12),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle_outline),
                                            color: const Color(0xFFFF5A1F),
                                            onPressed: selectedHours > 1 ? () {
                                              setState(() {
                                                selectedHours--;
                                                _calculateRentalPrice();
                                              });
                                            } : null,
                                          ),
                                          Container(
                                            width: 60,
                                            alignment: Alignment.center,
                                            child: Text(
                                              '$selectedHours hr',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF2B1B12),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add_circle_outline),
                                            color: const Color(0xFFFF5A1F),
                                            onPressed: selectedHours < 8 ? () {
                                              setState(() {
                                                selectedHours++;
                                                _calculateRentalPrice();
                                              });
                                            } : null,
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Text(
                                              '₹${(originalHourlyPrice * selectedHours).toStringAsFixed(0)} total',
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFFFF5A1F),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Note: Rental starts immediately for ${selectedHours} hour(s)',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF7D6C62),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Half Day Info
                              if (rentalDuration == 'halfday')
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5EFE9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline, color: Color(0xFFFF5A1F), size: 20),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Half day rental (12 hours) - ₹${originalHalfDayPrice.toStringAsFixed(0)}\nRental starts immediately',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF2B1B12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Custom Date/Time Picker
                              if (rentalDuration == 'custom')
                                Column(
                                  children: [
                                    // Start Date & Time
                                    Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => _selectStartDate(context),
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF5EFE9),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: const Color(0xFFE5D7C9),
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Start Date',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Color(0xFF7D6C62),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _formatDate(selectedStartDate),
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                      color: Color(0xFF2B1B12),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => _selectStartTime(context),
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF5EFE9),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: const Color(0xFFE5D7C9),
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Start Time',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Color(0xFF7D6C62),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _formatTime(selectedStartTime),
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                      color: Color(0xFF2B1B12),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // End Date & Time
                                    Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => _selectEndDate(context),
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF5EFE9),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: const Color(0xFFE5D7C9),
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'End Date',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Color(0xFF7D6C62),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _formatDate(selectedEndDate),
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                      color: Color(0xFF2B1B12),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => _selectEndTime(context),
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF5EFE9),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: const Color(0xFFE5D7C9),
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'End Time',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Color(0xFF7D6C62),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _formatTime(selectedEndTime),
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                      color: Color(0xFF2B1B12),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 12),

                                    // Duration Summary
                                    if (selectedStartDate != null && selectedEndDate != null)
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF7E9DF),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.access_time, color: Color(0xFFFF5A1F), size: 20),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                _getDurationSummary(),
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFFFF5A1F),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // NEW SECTION: car Photos Upload
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Car Photos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2B1B12),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Upload up to 10 photos of the car (Front, Back, Left, Right, License Plate, etc.)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7D6C62),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7F4),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              // Photo grid
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 1,
                                ),
                                itemCount: carPhotos.length + (carPhotos.length < 10 ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == carPhotos.length) {
                                    // Add photo button
                                    return GestureDetector(
                                      onTap: _pickcarPhoto,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF5EFE9),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: const Color(0xFFE5D7C9),
                                            style: BorderStyle.solid,
                                            width: 2,
                                          ),
                                        ),
                                        child: const Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.add_a_photo,
                                              size: 32,
                                              color: Color(0xFFFF5A1F),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'Add Photo',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF7D6C62),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }

                                  // Display photo
                                  return Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.file(
                                          carPhotos[index],
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () => _removecarPhoto(index),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.6),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),

                              if (carPhotos.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    '${carPhotos.length}/10 photos uploaded',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF10B981),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // NEW SECTION: Car Condition Checkbox
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7F4),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Checkbox(
                            value: iscarConditionFine,
                            onChanged: (bool? value) {
                              setState(() {
                                iscarConditionFine = value ?? false;
                              });
                            },
                            activeColor: const Color(0xFFFF5A1F),
                            checkColor: Colors.white,
                          ),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Car Condition Confirmation',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2B1B12),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'I confirm that the car is in good working condition with no damages, all lights, brakes, and indicators are functioning properly.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF7D6C62),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Price Breakup Section
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Price Breakup',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2B1B12),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7F4),
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
                              _buildPriceRow(
                                label: rentalDuration == 'hourly' ? 'Vehicle Rental ($selectedHours Hourly)' :
                                rentalDuration == 'halfday' ? 'Vehicle Rental (Half Day)' :
                                'Vehicle Rental',
                                amount: vehiclePrice,
                                icon: Icons.motorcycle,
                                isDark: isDark,
                              ),
                              const Divider(height: 1, color: Color(0xFFE5D7C9)),

                              if (discountPercentage > 0) ...[
                                _buildPriceRow(
                                  label: 'Discount ($discountPercentage% OFF)',
                                  amount: -(vehiclePrice * discountPercentage / 100),
                                  icon: Icons.local_offer,
                                  isDiscount: true,
                                  isDark: isDark,
                                ),
                                const Divider(height: 1, color: Color(0xFFE5D7C9)),
                              ],

                              if (discountPercentage > 0)
                                _buildPriceRow(
                                  label: 'Vehicle Rental (After Discount)',
                                  amount: discountedVehiclePrice,
                                  icon: Icons.motorcycle,
                                  isDark: isDark,
                                ),

                              if (discountPercentage > 0) const Divider(height: 1, color: Color(0xFFE5D7C9)),

                              _buildPriceRow(
                                label: 'Platform Fee',
                                amount: platformFee,
                                icon: Icons.devices,
                                isPlatformFee: true,
                                isDark: isDark,
                              ),
                              const Divider(height: 1, color: Color(0xFFE5D7C9)),

                              _buildPriceRow(
                                label: 'Total Amount',
                                amount: totalPrice,
                                icon: Icons.currency_rupee,
                                isBold: true,
                                isTotal: true,
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Partner Offer Section
                  if (widget.carData['offer'] != null &&
                      widget.carData['offer'].toString() != 'No Offer' &&
                      widget.carData['offer'] is Map &&
                      (widget.carData['offer']['discountPercentage'] ?? 0) > 0)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Available Offers',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2B1B12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFFF5A1F), Color(0xFFD97736)],
                              ),
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.local_offer,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${(widget.carData['offer']['discountPercentage'] ?? 0).toInt()}% OFF',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        'Special offer from partner',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(0.85),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isPartnerOfferApplied)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 24,
                                  )
                                else
                                  TextButton(
                                    onPressed: () {
                                      _applyPartnerOffer(
                                          (widget.carData['offer']['discountPercentage'] ?? 0).toDouble()
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFFFF5A1F),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('APPLY'),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (discountPercentage > 0)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '$discountPercentage% discount applied! You saved ₹${(vehiclePrice * discountPercentage / 100).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Terms & Conditions
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Center(
                      child: Text(
                        'By proceeding, you agree to our Terms & Conditions',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7D6C62),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Fixed Pay Now Button at bottom
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: GestureDetector(
              onTap: _initiatePayment,
              child: Container(
                width: double.infinity,
                height: 55,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5A1F),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5A1F).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'Pay Now  ₹${totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildDurationOption(String title, IconData icon, bool isSelected, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF5A1F)
              : const Color(0xFFF5EFE9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF5A1F)
                : const Color(0xFFE5D7C9),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF7D6C62),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : const Color(0xFF7D6C62),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'Select time';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _getDurationSummary() {
    if (selectedStartDate == null || selectedEndDate == null ||
        selectedStartTime == null || selectedEndTime == null) {
      return 'Select rental duration';
    }

    DateTime startDateTime = DateTime(
      selectedStartDate!.year,
      selectedStartDate!.month,
      selectedStartDate!.day,
      selectedStartTime!.hour,
      selectedStartTime!.minute,
    );

    DateTime endDateTime = DateTime(
      selectedEndDate!.year,
      selectedEndDate!.month,
      selectedEndDate!.day,
      selectedEndTime!.hour,
      selectedEndTime!.minute,
    );

    Duration difference = endDateTime.difference(startDateTime);
    int totalHours = difference.inHours;
    int totalDays = difference.inDays;

    if (totalDays > 0) {
      return 'Duration: $totalDays day(s) ${totalHours % 24} hour(s)';
    } else {
      return 'Duration: $totalHours hour(s)';
    }
  }

  Widget _buildPriceRow({
    required String label,
    required double amount,
    required IconData icon,
    required bool isDark,
    bool isBold = false,
    bool isTotal = false,
    bool isDiscount = false,
    bool isPlatformFee = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isPlatformFee
                  ? const Color(0xFFF59E0B).withOpacity(0.1)
                  : isDiscount
                  ? const Color(0xFF10B981).withOpacity(0.1)
                  : const Color(0xFFF7E9DF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isPlatformFee
                  ? const Color(0xFFF59E0B)
                  : isDiscount
                  ? const Color(0xFF10B981)
                  : const Color(0xFFFF5A1F),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
                color: isTotal
                    ? const Color(0xFF2B1B12)
                    : isDiscount
                    ? const Color(0xFF10B981)
                    : const Color(0xFF7D6C62),
              ),
            ),
          ),
          Text(
            '${amount >= 0 ? '₹' : '-₹'}${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isTotal
                  ? const Color(0xFFFF5A1F)
                  : isDiscount
                  ? const Color(0xFF10B981)
                  : const Color(0xFF2B1B12),
            ),
          ),
        ],
      ),
    );
  }
}

// Professional Success Screen with Animations
class SuccessScreen extends StatefulWidget {
  final String carName;
  final double totalAmount;
  final String rentalDuration;
  final bool isDarkMode;

  const SuccessScreen({
    super.key,
    required this.carName,
    required this.totalAmount,
    required this.rentalDuration,
    required this.isDarkMode,
  });

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();

    // Auto navigate after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getRentalTypeText() {
    switch (widget.rentalDuration) {
      case 'hourly':
        return 'Hourly Rental';
      case 'halfday':
        return 'Half Day Rental';
      case 'custom':
        return 'Custom Rental';
      default:
        return 'Full Day Rental';
    }
  }

  @override
  Widget build(BuildContext context) {
    const bool isDark = false;

    return Scaffold(
      backgroundColor: const Color(0xFFEDE1D5),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFEDE1D5),
        child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Success Icon
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFF5A1F),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF5A1F).withOpacity(0.4),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 70,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Congratulatory Message with Slide Animation
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7F4),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Congratulations! 🎉',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2B1B12),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Your booking has been confirmed',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF7D6C62),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          const Divider(
                            color: Color(0xFFE5D7C9),
                            height: 1,
                          ),
                          const SizedBox(height: 24),
                          _buildInfoRow(
                            Icons.motorcycle,
                            'car',
                            widget.carName,
                            isDark,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            Icons.currency_rupee,
                            'Amount Paid',
                            '₹${widget.totalAmount.toStringAsFixed(2)}',
                            isDark,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            Icons.access_time,
                            'Rental Type',
                            _getRentalTypeText(),
                            isDark,
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF5A1F), Color(0xFFD97736)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.white),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'You can view your booking details in the "My Rides" section',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
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
                const SizedBox(height: 32),

                // Continue Button with Fade Animation
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: double.infinity,
                        height: 55,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5A1F),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF5A1F).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'Continue to My Rides',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Auto-redirect note
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: const Text(
                    'Auto-redirecting in 3 seconds...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7D6C62),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF7E9DF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: const Color(0xFFFF5A1F),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF7D6C62),
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2B1B12),
          ),
        ),
      ],
    );
  }
}