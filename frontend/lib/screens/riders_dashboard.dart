// FILE: riders_dashboard.dart
// PURPOSE: Main dashboard page for riders - DARK MODE ONLY
// ALL BACKEND LOGIC, API CALLS, SOCKET CONNECTIONS, AND FUNCTIONALITY REMAIN UNCHANGED
// ONLY UI/UX HAS BEEN REDESIGNED - REMOVED DARK MODE TOGGLE

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'rider_pricebreakup.dart';
import 'rider_personalinformation.dart';
import 'rider_helpsupport.dart';
import 'about_carrzzzriders.dart';
import '../widgets/app_icon_or_image.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class RidersDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const RidersDashboard({
    super.key,
    required this.userData,
  });

  @override
  State<RidersDashboard> createState() => _RidersDashboardState();
}

// Ride model class - UNCHANGED
class Ride {
  final String id;
  final String carName;
  final String carModel;
  final double amount;
  final DateTime bookingDate;
  final String status;
  final String paymentId;
  final String carId;
  final DateTime? startDateTime;
  final DateTime? endDateTime;
  final DateTime? handoverDate;
  final String rentalType;

  Ride({
    required this.id,
    required this.carName,
    required this.carModel,
    required this.amount,
    required this.bookingDate,
    required this.status,
    required this.paymentId,
    required this.carId,
    this.startDateTime,
    this.endDateTime,
    this.handoverDate,
    this.rentalType = 'fullday',
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
      id: json['_id'] ?? json['id'] ?? '',
      carName: json['carName'] ?? json['carModel'],
      carModel: json['carModel'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      bookingDate: DateTime.parse(json['bookingDate'] ?? json['createdAt']),
      status: json['status'] ?? 'active',
      paymentId: json['paymentId'] ?? '',
      carId: json['carId'] ?? '',
      startDateTime: json['rentalDetails']?['startDateTime'] != null
          ? DateTime.parse(json['rentalDetails']['startDateTime'])
          : null,
      endDateTime: json['rentalDetails']?['endDateTime'] != null
          ? DateTime.parse(json['rentalDetails']['endDateTime'])
          : null,
      handoverDate: json['handoverDate'] != null
          ? DateTime.parse(json['handoverDate'])
          : null,
      rentalType: json['rentalDetails']?['rentalType'] ?? 'fullday',
    );
  }
}

// Review model class - UNCHANGED
class CarReview {
  final String id;
  final String userName;
  final double rating;
  final String comment;
  final DateTime createdAt;

  CarReview({
    required this.id,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory CarReview.fromJson(Map<String, dynamic> json) {
    return CarReview(
      id: json['_id'] ?? json['id'],
      userName: json['userName'] ?? json['user'] ?? 'Anonymous',
      rating: (json['rating'] as num).toDouble(),
      comment: json['comment'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}

class _RidersDashboardState extends State<RidersDashboard> {
  // ========== ALL VARIABLES - UNCHANGED ==========
  IO.Socket? _socket;
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  bool _showFilterMenu = false;
  String _selectedFilter = 'All';
  final GlobalKey _filterButtonKey = GlobalKey();
  String _availablecarsTitle = 'Available Cars';

  static const int _connectionTimeout = 30;
  static const int _autoRefreshInterval = 30;
  static const bool _usePhysicalDevice = false;

  String get _baseUrl {
    if (_usePhysicalDevice) {
      return 'http://10.0.2.2:3000/api';
    } else {
      return 'https://carzzz-frontend.onrender.com/api';
    }
  }

  String _getSocketUrl() {
    if (_usePhysicalDevice) {
      return 'http://10.0.2.2:3000';
    } else {
      return 'https://carzzz-frontend.onrender.com';
    }
  }

  Set<String> _reservedcarIds = {};
  Timer? _reservationCheckTimer;

  bool _isLoadingcars = true;
  bool _isLoadingLocation = true;

  Position? _currentPosition;
  String _locationError = '';

  List<Map<String, dynamic>> _allcars = [];
  List<Map<String, dynamic>> _nearbycars = [];
  List<Map<String, dynamic>> _filteredcars = [];

  Timer? _autoRefreshTimer;
  Timer? _silentRefreshTimer;

  List<Ride> _myRides = [];
  bool _isLoadingRides = false;
  Timer? _ridesRefreshTimer;

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  final List<String> _filterOptions = [
    'All',
    'Newly Added Cars',
    'Recommended Cars',
    'Sports Car',
    'Super Cars',
    'Casual Car',
    'Electric Car',
    'Petrol Car',
    'Sort by Low to High',
    'Sort by High to Low',
  ];

  // ========== HELPER METHODS - UNCHANGED ==========
  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getRentalTypeText(String type) {
    switch (type) {
      case 'hourly': return 'Hourly Rental';
      case 'halfday': return 'Half Day Rental';
      case 'fullday': return 'Full Day Rental';
      default: return 'Standard Rental';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getOfferText(dynamic offer) {
    if (offer == null) return '';

    if (offer is Map) {
      final dynamic rawDiscount = offer['discountPercentage'] ??
          offer['discount'] ??
          offer['percentage'] ??
          offer['percent'];
      final num? discount = rawDiscount is num
          ? rawDiscount
          : num.tryParse(rawDiscount?.toString().trim() ?? '');
      if (discount != null && discount > 0) {
        return '${discount % 1 == 0 ? discount.toInt() : discount}% OFF';
      }
      final dynamic label = offer['title'] ?? offer['label'] ?? offer['text'];
      if (label is String &&
          label.trim().isNotEmpty &&
          label.trim() != 'No Offer') {
        return label.trim();
      }
      return '';
    }

    if (offer is num && offer > 0) {
      return '${offer % 1 == 0 ? offer.toInt() : offer}% OFF';
    }

    if (offer is String) {
      final String trimmed = offer.trim();
      if (trimmed.isEmpty ||
          trimmed == 'No Offer' ||
          trimmed.toLowerCase() == 'null') {
        return '';
      }
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try {
          final decoded = json.decode(trimmed);
          if (decoded is Map) return _getOfferText(decoded);
        } catch (_) {}
      }
      final num? numericOffer = num.tryParse(trimmed);
      if (numericOffer != null && numericOffer > 0) {
        return '${numericOffer % 1 == 0 ? numericOffer.toInt() : numericOffer}% OFF';
      }
      return trimmed;
    }

    return '';
  }

  // ========== ALL BACKEND METHODS - UNCHANGED ==========

  @override
  void initState() {
    super.initState();
    _initSocket();
    _requestLocationPermission();
    _startSilentRefreshTimer();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _ridesRefreshTimer?.cancel();
    _reservationCheckTimer?.cancel();
    _silentRefreshTimer?.cancel();
    _searchController.dispose();
    _socket?.disconnect();
    super.dispose();
  }

  void _startSilentRefreshTimer() {
    _silentRefreshTimer = Timer.periodic(
      const Duration(seconds: 10),
          (timer) {
        if (mounted && _selectedIndex == 0) {
          _silentRefreshcars();
        }
      },
    );
  }

  Future<void> _silentRefreshcars() async {
    try {
      print('🔄 Silent refreshing cars...');
      final response = await http.get(
        Uri.parse('$_baseUrl/partner/cars'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: _connectionTimeout));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['cars'] != null) {
          final carsList = data['cars'] as List;
          final String currentUserId = widget.userData['id']?.toString() ?? widget.userData['_id']?.toString() ?? '';
          final availablecars = carsList.where((car) {
            final status = car['status'];
            if (status == 'available') return true;
            if ((status == 'held' || status == 'hold') &&
                (car['heldBy'] == currentUserId || _reservedcarIds.contains(car['_id'] ?? car['id']))) {
              return true;
            }
            return false;
          }).toList();

          final processedcars = availablecars.map((car) {
            double ratingValue = 4.0;
            if (car['rating'] != null) {
              if (car['rating'] is int) {
                ratingValue = (car['rating'] as int).toDouble();
              } else if (car['rating'] is double) {
                ratingValue = car['rating'] as double;
              } else if (car['rating'] is num) {
                ratingValue = (car['rating'] as num).toDouble();
              }
            }

            List<CarReview> reviews = [];
            if (car['reviews'] != null && car['reviews'] is List) {
              reviews = (car['reviews'] as List)
                  .map((r) => CarReview.fromJson(r))
                  .toList();
            } else {
              reviews = _getSampleReviews(ratingValue);
            }

            dynamic offerValue = car['offer'] ?? car['discountPercentage'] ?? car['discount'];
            if (offerValue != null &&
                offerValue is! Map &&
                offerValue is! String &&
                offerValue is! num) {
              offerValue = offerValue.toString();
            }

            return {
              'id': car['_id'] ?? car['id'],
              'name': car['model'],
              'price': car['dailyRate'],
              'priceText': '₹${car['dailyRate']}/day',
              'distance': _calculateDistanceFromcar(car),
              'rating': ratingValue,
              'category': _getCategoryFromType(car['type']),
              'type': car['type'],
              'description': car['description'] ?? 'Experience the thrill of riding this premium car.',
              'photos': car['images']?.isNotEmpty == true ? car['images'] : _getDefaultImages(car['model']),
              'reviews': reviews,
              'location': car['location'],
              'status': car['status'],
              'fuelType': car['fuelType'],
              'partner': car['partner'],
              'offer': offerValue,
            };
          }).toList();

          if (mounted) {
            setState(() {
              _allcars = processedcars;

              if (_currentPosition != null) {
                _nearbycars = _allcars.where((car) {
                  double distance = car['distance'] as double;
                  return distance <= 10.0;
                }).toList();
                _nearbycars.sort((a, b) =>
                    (a['distance'] as double).compareTo(b['distance'] as double)
                );
              } else {
                _nearbycars = List.from(_allcars);
              }

              _filtercars(_selectedFilter);
            });
            print('✅ Silent refresh completed: ${_allcars.length} cars loaded');
          }
        }
      }
    } catch (e) {
      print('❌ Silent refresh error: $e');
    }
  }

  Future<void> _reservecar(String carId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) return;

      print('🔒 Attempting to create hold for car: $carId');

      // Use the hold endpoint instead of reserve
      final response = await http.post(
        Uri.parse('$_baseUrl/cars/hold'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'carId': carId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('✅ Car hold created successfully for 10 minutes');
          setState(() {
            _reservedcarIds.add(carId);
          });
          await _loadcarsFromBackend();
          _startReservationChecker();
        }
      } else if (response.statusCode == 409) {
        final data = json.decode(response.body);
        print('⚠️ Car already held: ${data['message']}');
        _showSnackBar(data['message'] ?? 'This car is currently being booked by another user');
      } else {
        print('⚠️ Hold creation failed: ${response.statusCode}');
        _showSnackBar('Could not book this car. Please try again.');
      }
    } catch (e) {
      print('❌ Error creating hold: $e');
      _showSnackBar('Network error. Please try again.');
    }
  }

  Future<void> _releasecar(String carId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      print('🔓 Releasing hold for car: $carId');

      if (token != null) {
        await Future.wait([
          http.delete(
            Uri.parse('$_baseUrl/cars/hold/$carId'),
            headers: {'Authorization': 'Bearer $token'},
          ).catchError((_) => http.Response('', 500)),
          http.delete(
            Uri.parse('$_baseUrl/cars/release-reservation/$carId'),
            headers: {'Authorization': 'Bearer $token'},
          ).catchError((_) => http.Response('', 500)),
        ]);
      }

      if (mounted) {
        setState(() {
          _reservedcarIds.remove(carId);
        });
        await _loadcarsFromBackend();
      }
    } catch (e) {
      print('❌ Error releasing car hold: $e');
    }
  }
  Future<void> _requestLocationPermission() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = '';
    });

    try {
      PermissionStatus status = await Permission.location.request();

      if (status.isGranted) {
        _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        print('📍 Location obtained: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
        await _loadcarsFromBackend();
      } else if (status.isDenied) {
        setState(() {
          _locationError = 'Location permission denied. Please enable location to see nearby cars.';
        });
        await _loadcarsFromBackend();
      } else if (status.isPermanentlyDenied) {
        setState(() {
          _locationError = 'Location permission permanently denied. Please enable in settings.';
        });
        await _loadcarsFromBackend();
      }
    } catch (e) {
      print('Location error: $e');
      setState(() {
        _locationError = 'Unable to get location: ${e.toString()}';
      });
      await _loadcarsFromBackend();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371;
    double dLat = (lat2 - lat1) * math.pi / 180;
    double dLon = (lon2 - lon1) * math.pi / 180;
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  Future<void> _loadcarsFromBackend({int retryCount = 0}) async {
    if (!mounted) return;

    setState(() {
      _isLoadingcars = true;
    });

    try {
      print('🔄 Fetching cars from backend...');
      final response = await http.get(
        Uri.parse('$_baseUrl/partner/cars'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: _connectionTimeout));

      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📦 Response data: ${data['success']}, Count: ${data['count']}');

        if (data['success'] == true && data['cars'] != null) {
          final carsList = data['cars'] as List;
          print('✅ Received ${carsList.length} cars from backend');

          final String currentUserId = widget.userData['id']?.toString() ?? widget.userData['_id']?.toString() ?? '';
          final availablecars = carsList.where((car) {
            final status = car['status'];
            if (status == 'available') return true;
            if ((status == 'held' || status == 'hold') &&
                (car['heldBy'] == currentUserId || _reservedcarIds.contains(car['_id'] ?? car['id']))) {
              return true;
            }
            return false;
          }).toList();

          print('📊 Available cars count: ${availablecars.length}');

          _allcars = availablecars.map((car) {
            double ratingValue = 4.0;
            if (car['rating'] != null) {
              if (car['rating'] is int) {
                ratingValue = (car['rating'] as int).toDouble();
              } else if (car['rating'] is double) {
                ratingValue = car['rating'] as double;
              } else if (car['rating'] is num) {
                ratingValue = (car['rating'] as num).toDouble();
              }
            }

            List<CarReview> reviews = [];
            if (car['reviews'] != null && car['reviews'] is List) {
              reviews = (car['reviews'] as List)
                  .map((r) => CarReview.fromJson(r))
                  .toList();
            } else {
              reviews = _getSampleReviews(ratingValue);
            }

            dynamic offerValue = car['offer'] ?? car['discountPercentage'] ?? car['discount'];
            if (offerValue != null &&
                offerValue is! Map &&
                offerValue is! String &&
                offerValue is! num) {
              offerValue = offerValue.toString();
            }

            return {
              'id': car['_id'] ?? car['id'],
              'name': car['model'],
              'price': car['dailyRate'],
              'priceText': '₹${car['dailyRate']}/day',
              'distance': _calculateDistanceFromcar(car),
              'rating': ratingValue,
              'category': _getCategoryFromType(car['type']),
              'type': car['type'],
              'description': car['description'] ?? 'Experience the thrill of riding this premium car.',
              'photos': car['images']?.isNotEmpty == true ? car['images'] : _getDefaultImages(car['model']),
              'reviews': reviews,
              'location': car['location'],
              'status': car['status'],
              'fuelType': car['fuelType'],
              'partner': car['partner'],
              'offer': offerValue,
            };
          }).toList();

          if (_reservedcarIds.isNotEmpty) {
            final String currentUserId = widget.userData['id']?.toString() ?? '';
            _allcars = _allcars.where((car) {
              if (_reservedcarIds.contains(car['id'])) return true;
              return true;
            }).toList();
            print('📊 After filtering reservations: ${_allcars.length} cars');
          }

          if (_currentPosition != null) {
            _nearbycars = _allcars.where((car) {
              double distance = car['distance'] as double;
              return distance <= 10.0;
            }).toList();
            _nearbycars.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
            print('📍 Nearby cars count (within 10km): ${_nearbycars.length}');
          } else {
            _nearbycars = List.from(_allcars);
            print('📍 Location not available - showing all cars as nearby');
          }

          _filteredcars = List.from(_allcars);
        } else {
          print('⚠️ No cars data in response');
          setState(() {
            _allcars = [];
            _nearbycars = [];
            _filteredcars = [];
          });
        }
      } else {
        print('❌ Backend error: ${response.statusCode}');
        if (retryCount < 2) {
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            await _loadcarsFromBackend(retryCount: retryCount + 1);
          }
        } else {
          setState(() {
            _allcars = [];
            _nearbycars = [];
            _filteredcars = [];
          });
        }
      }
    } catch (e) {
      print('❌ Error loading cars from backend: $e');
      if (retryCount < 2) {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          await _loadcarsFromBackend(retryCount: retryCount + 1);
        }
      } else {
        setState(() {
          _allcars = [];
          _nearbycars = [];
          _filteredcars = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingcars = false;
        });
      }
    }
  }

  double _calculateDistanceFromcar(Map<String, dynamic> car) {
    if (_currentPosition == null) return 0.5;

    final location = car['location'];
    if (location == null) return 0.5;

    final latValue = location['lat'];
    final lngValue = location['lng'];

    if (latValue == null || lngValue == null) return 0.5;

    double carLat;
    double carLng;

    if (latValue is int) {
      carLat = latValue.toDouble();
    } else if (latValue is double) {
      carLat = latValue;
    } else if (latValue is num) {
      carLat = latValue.toDouble();
    } else {
      return 0.5;
    }

    if (lngValue is int) {
      carLng = lngValue.toDouble();
    } else if (lngValue is double) {
      carLng = lngValue;
    } else if (lngValue is num) {
      carLng = lngValue.toDouble();
    } else {
      return 0.5;
    }

    return _calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      carLat,
      carLng,
    );
  }

  String _getCategoryFromType(String type) {
    switch (type.toLowerCase()) {
      case 'scooter':
        return 'Casual Car';
      case 'motorcycle':
        return 'Sports Car';
      case 'electric':
        return 'Electric Car';
      case 'sports car':
        return 'Sports Car';
      default:
        return 'Casual Car';
    }
  }

  List<String> _getDefaultImages(String carName) {
    return [
      'https://via.placeholder.com/400x300/3B82F6/FFFFFF?text=${Uri.encodeComponent(carName)}+1',
      'https://via.placeholder.com/400x300/60A5FA/FFFFFF?text=${Uri.encodeComponent(carName)}+2',
      'https://via.placeholder.com/400x300/3B82F6/FFFFFF?text=${Uri.encodeComponent(carName)}+3',
    ];
  }

  List<CarReview> _getSampleReviews(double rating) {
    int intRating = rating.round();
    return [
      CarReview(
        id: '1',
        userName: 'Happy Customer',
        rating: intRating.toDouble(),
        comment: 'Great car, well maintained!',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      CarReview(
        id: '2',
        userName: 'Satisfied Rider',
        rating: (intRating - 1).toDouble(),
        comment: 'Good experience overall.',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ];
  }

  void _startReservationChecker() {
    _reservationCheckTimer?.cancel();
    _reservationCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await _checkReservationStatus();
    });
  }

  Future<void> _checkReservationStatus() async {
    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) return;

      // Check holds using the hold endpoint
      final response = await http.get(
        Uri.parse('$_baseUrl/cars/my-reservations'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final activeReservations = Set<String>.from(data['reservedCarIds'] ?? []);

          if (mounted) {
            setState(() {
              _reservedcarIds = activeReservations;
            });
          }

          await _loadcarsFromBackend();

          print('📊 Active holds: ${_reservedcarIds.length}');
        }
      }
    } catch (e) {
      print('❌ Error checking holds: $e');
    }
  }
  void _updateExistingcar(Map<String, dynamic> updatedcar) {
    final String carId = updatedcar['_id'] ?? updatedcar['carId'];

    dynamic offerValue = updatedcar['offer'];
    if (offerValue != null && offerValue is! Map && offerValue is! String) {
      offerValue = offerValue.toString();
    }

    final formattedcar = {
      'id': carId,
      'name': updatedcar['model'],
      'price': updatedcar['dailyRate'],
      'priceText': '₹${updatedcar['dailyRate']}/day',
      'distance': _currentPosition != null && updatedcar['location'] != null
          ? _calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        (updatedcar['location']['lat'] as num).toDouble(),
        (updatedcar['location']['lng'] as num).toDouble(),
      )
          : 0.5,
      'rating': (updatedcar['rating'] as num?)?.toDouble() ?? 4.0,
      'category': _getCategoryFromType(updatedcar['type']),
      'type': updatedcar['type'],
      'description': updatedcar['description'] ?? 'Experience the thrill of riding this premium car.',
      'photos': updatedcar['images']?.isNotEmpty == true ? updatedcar['images'] : _getDefaultImages(updatedcar['model']),
      'reviews': _getSampleReviews(updatedcar['rating']?.toDouble() ?? 4.0),
      'location': updatedcar['location'],
      'status': updatedcar['status'],
      'fuelType': updatedcar['fuelType'],
      'partner': updatedcar['partner'],
      'offer': offerValue,
    };

    setState(() {
      _updatecarInList(_allcars, carId, formattedcar);
      _updatecarInList(_nearbycars, carId, formattedcar);
      _updatecarInList(_filteredcars, carId, formattedcar);

      if (_currentPosition != null) {
        _nearbycars.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
      }
    });
  }

  void _updatecarInList(List<Map<String, dynamic>> list, String carId, Map<String, dynamic> updatedcar) {
    int index = list.indexWhere((car) => car['id'] == carId);
    if (index != -1) {
      list[index] = updatedcar;
    }
  }

  void _initSocket() {
    try {
      _socket = IO.io(_getSocketUrl(), <String, dynamic>{
        'transports': ['polling', 'websocket'],
        'autoConnect': true,
      });

      _socket!.onConnect((_) {
        print('🔌 Socket connected for rider');
        final userId = widget.userData['id']?.toString();
        if (userId != null && _socket != null) {
          _socket!.emit('join_rider_room', userId);
        }
      });

      _socket!.on('new_car_added', (dynamic data) {
        print('📱 New car received in real-time: ${data['model']}');
        _silentRefreshcars();
        _showSnackBar('New car "${data['model']}" added!');
      });

      _socket!.on('car_uploaded', (dynamic data) {
        print('📱 car uploaded by partner: ${data['model']}');
        _silentRefreshcars();
        _showSnackBar('New car "${data['model']}" added!');
      });

      _socket!.on('car_updated', (dynamic data) {
        print('📱 car updated: ${data['model']}');
        _silentRefreshcars();
        _showSnackBar('Car "${data['model']}" updated!');
      });

      _socket!.on('car_review_added', (dynamic data) {
        print('📱 New review received: ${data['review']['userName']} rated ${data['review']['rating']} stars');
        _updatecarWithNewReview(data);
      });

      _socket!.on('car_status_updated', (dynamic data) {
        print('📱 car status updated: ${data['carId']} - ${data['status']}');
        if (data['status'] == 'rented') {
          _removeRentedcar(data['carId']);
        }
      });

      _socket!.on('new_order_created', (dynamic data) {
        print('📱 New order created: ${data['orderId']}');
        if (mounted && _selectedIndex == 1) {
          _loadMyRides();
          _showSnackBar('Your booking is confirmed!');
        }
      });

      _socket!.on('order_status_updated', (dynamic data) {
        print('📱 Order status updated: ${data['orderId']} - ${data['status']}');
        if (mounted && _selectedIndex == 1) {
          _loadMyRides();
        }
      });

      _socket!.onDisconnect((_) {
        print('🔌 Socket disconnected');
      });

      _socket!.connect();
    } catch (e) {
      print('Error initializing socket: $e');
    }
  }

  void _addNewcarToLists(Map<String, dynamic> newcar) {
    dynamic offerValue = newcar['offer'];
    if (offerValue != null && offerValue is! Map && offerValue is! String) {
      offerValue = offerValue.toString();
    }
    final formattedcar = {
      'id': newcar['_id'] ?? newcar['id'],
      'name': newcar['model'],
      'price': newcar['dailyRate'],
      'priceText': '₹${newcar['dailyRate']}/day',
      'distance': _currentPosition != null && newcar['location'] != null
          ? _calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        (newcar['location']['lat'] as num).toDouble(),
        (newcar['location']['lng'] as num).toDouble(),
      )
          : 0.5,
      'rating': (newcar['rating'] as num?)?.toDouble() ?? 4.0,
      'category': _getCategoryFromType(newcar['type']),
      'type': newcar['type'],
      'description': newcar['description'] ?? 'Experience the thrill of riding this premium car.',
      'photos': newcar['images']?.isNotEmpty == true ? newcar['images'] : _getDefaultImages(newcar['model']),
      'reviews': _getSampleReviews(newcar['rating']?.toDouble() ?? 4.0),
      'location': newcar['location'],
      'status': newcar['status'],
      'fuelType': newcar['fuelType'],
      'partner': newcar['partner'],
      'offer': offerValue,
    };

    setState(() {
      _allcars.insert(0, formattedcar);

      if (_currentPosition != null) {
        double distance = formattedcar['distance'] as double;
        if (distance <= 10.0) {
          _nearbycars.insert(0, formattedcar);
          _nearbycars.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
        }
      } else {
        _nearbycars.insert(0, formattedcar);
      }

      _filtercars(_selectedFilter);
    });

    _showSnackBar('New car "${newcar['model']}" added nearby!');
  }

  void _filtercars(String filter) {
    setState(() {
      _selectedFilter = filter;
      _availablecarsTitle = filter == 'All' ? 'Available Cars' : filter;

      if (filter == 'All') {
        _filteredcars = List.from(_allcars);
      } else if (filter == 'Sort by Low to High') {
        _filteredcars = List.from(_allcars)
          ..sort((a, b) => a['price'].compareTo(b['price']));
      } else if (filter == 'Sort by High to Low') {
        _filteredcars = List.from(_allcars)
          ..sort((a, b) => b['price'].compareTo(a['price']));
      } else if (filter == 'Newly Added Cars') {
        _filteredcars = List.from(_allcars)
          ..sort((a, b) => b['id'].toString().compareTo(a['id'].toString()));
      } else {
        _filteredcars = _allcars
            .where((car) => car['category'] == filter)
            .toList();
      }
    });
  }

  void _removeRentedcar(String carId) {
    setState(() {
      _allcars.removeWhere((car) => car['id'] == carId);
      _nearbycars.removeWhere((car) => car['id'] == carId);
      _filteredcars.removeWhere((car) => car['id'] == carId);
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFF5A1F),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFF5A1F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Future<void> _addReview(Map<String, dynamic> car, String userName, double rating, String comment) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        _showSnackBar('Please login to add a review');
        return;
      }

      _showSnackBar('Posting your review...');

      final response = await http.post(
        Uri.parse('$_baseUrl/partner/cars/${car['id']}/review'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'rating': rating,
          'comment': comment,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final newReview = CarReview(
            id: data['review']['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
            userName: data['review']['userName'] ?? userName,
            rating: rating,
            comment: comment,
            createdAt: DateTime.now(),
          );

          setState(() {
            final carIndex = _allcars.indexWhere((b) => b['id'] == car['id']);
            if (carIndex != -1) {
              final reviewsList = List<CarReview>.from(_allcars[carIndex]['reviews']);
              reviewsList.insert(0, newReview);
              _allcars[carIndex]['reviews'] = reviewsList;
              if (rating > 0) {
                final totalRating = reviewsList.fold<double>(0, (sum, r) => sum + r.rating);
                _allcars[carIndex]['rating'] = totalRating / reviewsList.length;
              }
            }

            final nearbyIndex = _nearbycars.indexWhere((b) => b['id'] == car['id']);
            if (nearbyIndex != -1) {
              final reviewsList = List<CarReview>.from(_nearbycars[nearbyIndex]['reviews']);
              reviewsList.insert(0, newReview);
              _nearbycars[nearbyIndex]['reviews'] = reviewsList;
              if (rating > 0) {
                final totalRating = reviewsList.fold<double>(0, (sum, r) => sum + r.rating);
                _nearbycars[nearbyIndex]['rating'] = totalRating / reviewsList.length;
              }
            }

            final filteredIndex = _filteredcars.indexWhere((b) => b['id'] == car['id']);
            if (filteredIndex != -1) {
              final reviewsList = List<CarReview>.from(_filteredcars[filteredIndex]['reviews']);
              reviewsList.insert(0, newReview);
              _filteredcars[filteredIndex]['reviews'] = reviewsList;
              if (rating > 0) {
                final totalRating = reviewsList.fold<double>(0, (sum, r) => sum + r.rating);
                _filteredcars[filteredIndex]['rating'] = totalRating / reviewsList.length;
              }
            }
          });

          _showSnackBar('Review posted successfully!');
        } else {
          _showSnackBar(data['message'] ?? 'Failed to add review');
        }
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(errorData['message'] ?? 'Failed to add review');
      }
    } catch (e) {
      print('Error adding review: $e');
      _showSnackBar('Network error. Please try again.');
    }
  }

  // ========== FIXED METHOD - Changed variable name from 'CarReview' to 'newReviewObject' ==========
  void _updatecarWithNewReview(Map<String, dynamic> reviewData) {
    final String carId = reviewData['carId'];
    final Map<String, dynamic> newReview = reviewData['review'];
    final double newRating = reviewData['newRating'];
    final int newReviewCount = reviewData['reviewCount'];

    setState(() {
      final carIndex = _allcars.indexWhere((car) => car['id'] == carId);
      if (carIndex != -1) {
        // FIX: Changed variable name from 'CarReview' to 'newReviewObject'
        final CarReview newReviewObject = CarReview(
          id: newReview['id'],
          userName: newReview['userName'],
          rating: (newReview['rating'] as num).toDouble(),
          comment: newReview['comment'],
          createdAt: DateTime.parse(newReview['createdAt']),
        );

        final reviewsList = List<CarReview>.from(_allcars[carIndex]['reviews']);
        reviewsList.insert(0, newReviewObject);
        _allcars[carIndex]['reviews'] = reviewsList;
        _allcars[carIndex]['rating'] = newRating;

        final nearbyIndex = _nearbycars.indexWhere((b) => b['id'] == carId);
        if (nearbyIndex != -1) {
          _nearbycars[nearbyIndex]['reviews'] = reviewsList;
          _nearbycars[nearbyIndex]['rating'] = newRating;
        }

        final filteredIndex = _filteredcars.indexWhere((b) => b['id'] == carId);
        if (filteredIndex != -1) {
          _filteredcars[filteredIndex]['reviews'] = reviewsList;
          _filteredcars[filteredIndex]['rating'] = newRating;
        }
      }
    });

    _showSnackBar('New review added for this car!');
  }

  void _showAddReviewPopup(Map<String, dynamic> car) {
    double selectedRating = 0;
    final TextEditingController reviewController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setStatePopup) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFFAF7F4),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5D7C9),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Rate Your Experience',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B1B12),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  car['name'],
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF7D6C62),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () {
                        setStatePopup(() {
                          selectedRating = (index + 1).toDouble();
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          index < selectedRating ? Icons.star : Icons.star_border,
                          size: 40,
                          color: const Color(0xFFFF5A1F),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  selectedRating > 0 ? '${selectedRating.toStringAsFixed(1)} stars' : 'Tap to rate (optional)',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF7D6C62),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: reviewController,
                    maxLines: 3,
                    style: const TextStyle(color: Color(0xFF2B1B12)),
                    decoration: InputDecoration(
                      hintText: 'Write your review here... *',
                      hintStyle: const TextStyle(
                        color: Color(0xFF9A8B82),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFE5D7C9),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFE5D7C9),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFFF5A1F)),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF5EFE9),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6D6C8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: OutlinedButton(
                            onPressed: isSubmitting ? null : () {
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: Color(0xFF2B1B12),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5A1F),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ElevatedButton(
                            onPressed: isSubmitting ? null : () {
                              if (reviewController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please write a review'),
                                    backgroundColor: Color(0xFFFF5A1F),
                                  ),
                                );
                                return;
                              }

                              final userName = widget.userData['fullname']?.split(' ')[0] ?? 'User';
                              Navigator.pop(context);
                              _addReview(
                                  car,
                                  userName,
                                  selectedRating,
                                  reviewController.text.trim()
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                                : const Text('Submit Review'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  void _silentRefreshReviews() {
    _silentRefreshcars();
  }

  void _showcarDetailPopup(Map<String, dynamic> car) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setStatePopup) {
          int currentImageIndex = 0;
          final reviewsList = car['reviews'] as List<CarReview>;

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Color(0xFFFAF7F4),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5D7C9),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 300,
                          child: Stack(
                            children: [
                              PageView.builder(
                                itemCount: (car['photos'] as List).length,
                                onPageChanged: (index) {
                                  setStatePopup(() {
                                    currentImageIndex = index;
                                  });
                                },
                                itemBuilder: (context, index) {
                                  return Container(
                                    margin: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      image: DecorationImage(
                                        image: NetworkImage(car['photos'][index]),
                                        fit: BoxFit.cover,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              Positioned(
                                bottom: 20,
                                left: 0,
                                right: 0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    (car['photos'] as List).length,
                                        (index) => Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: currentImageIndex == index
                                            ? const Color(0xFFFF5A1F)
                                            : Colors.white.withOpacity(0.6),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  car['name'],
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2B1B12),
                                  ),
                                ),
                              ),
                              Text(
                                car['priceText'],
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF5A1F),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.star, size: 18, color: Color(0xFFFF5A1F)),
                                  const SizedBox(width: 4),
                                  Text(
                                    car['rating'].toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2B1B12),
                                    ),
                                  ),
                                  Text(
                                    ' (${reviewsList.length} reviews)',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF7D6C62),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 18, color: Color(0xFF7D6C62)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${(car['distance'] as double).toStringAsFixed(1)} km',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF7D6C62),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Description',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2B1B12),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5EFE9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFE5D7C9),
                                  ),
                                ),
                                child: Text(
                                  car['description'],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF2B1B12),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Reviews',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2B1B12),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  _showAddReviewPopup(car);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF5A1F),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.edit_note, size: 16, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text(
                                        'Write Review',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: reviewsList.isEmpty
                              ? Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5EFE9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE5D7C9),
                              ),
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.rate_review,
                                    size: 48,
                                    color: const Color(0xFF7D6C62).withOpacity(0.6),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'No reviews yet',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF2B1B12),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Be the first to review this car!',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF7D6C62),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                              : Column(
                            children: List.generate(
                              reviewsList.length,
                                  (index) {
                                var review = reviewsList[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
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
                                      Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFF7E9DF),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Center(
                                              child: Icon(
                                                Icons.person,
                                                size: 16,
                                                color: Color(0xFFFF5A1F),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              review.userName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF2B1B12),
                                              ),
                                            ),
                                          ),
                                          Row(
                                            children: List.generate(
                                              5,
                                                  (starIndex) => Icon(
                                                starIndex < review.rating
                                                    ? Icons.star
                                                    : Icons.star_border,
                                                size: 14,
                                                color: const Color(0xFFFF5A1F),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        review.comment,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF7D6C62),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDate(review.createdAt),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF9A8B82),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: GestureDetector(
                            onTap: () async {
                              Navigator.pop(context);
                              await _reservecar(car['id']);
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RiderPriceBreakup(
                                    carData: car,
                                    userData: widget.userData,
                                    isDarkMode: false,
                                  ),
                                ),
                              );

                              if (result != null && result == true) {
                                setState(() {
                                  _selectedIndex = 1;
                                });
                                await Future.delayed(const Duration(milliseconds: 500));
                                await _loadMyRides();
                                _showSnackBar('Your car is booked! Check your ongoing ride in My Rides.');
                              } else {
                                // User backed out without paying - release hold immediately
                                await _releasecar(car['id']);
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.only(bottom: 4.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFCC3F0C),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFCC3F0C).withOpacity(0.40),
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
                                    colors: [Color(0xFFFF7A47), Color(0xFFFF5A1F), Color(0xFFE64A12)],
                                    stops: [0.0, 0.45, 1.0],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.35),
                                    width: 1,
                                  ),
                                ),
                                child: const Center(
                                  child: Text(
                                    'Rent Now',
                                    style: TextStyle(
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
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ========== RIDES METHODS ==========
  Future<void> _loadMyRides() async {
    if (!mounted) return;

    setState(() {
      _isLoadingRides = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        setState(() {
          _isLoadingRides = false;
          _myRides = [];
        });
        return;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/rides/my-rides'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['rides'] != null) {
          final ridesList = data['rides'] as List;
          final DateTime now = DateTime.now();

          setState(() {
            _myRides = ridesList
                .map((ride) => Ride.fromJson(ride))
                .where((ride) =>
            ride.status != 'cancelled' &&
                ride.status != 'completed' &&
                ride.handoverDate == null
            )
                .toList();

            print('✅ Loaded ${_myRides.length} active rides');
            print('📊 Ride statuses: ${_myRides.map((r) => r.status).toList()}');

            _myRides.sort((a, b) {
              if (a.startDateTime != null && b.startDateTime != null) {
                return b.startDateTime!.compareTo(a.startDateTime!);
              }
              if (a.startDateTime != null) return -1;
              if (b.startDateTime != null) return 1;
              return b.bookingDate.compareTo(a.bookingDate);
            });
          });
        } else {
          print('⚠️ Failed to load rides: ${response.statusCode}');
          setState(() {
            _myRides = [];
          });
        }
      } else {
        print('⚠️ Failed to load rides: ${response.statusCode}');
        setState(() {
          _myRides = [];
        });
      }
    } catch (e) {
      print('❌ Error loading rides: $e');
      if (mounted) {
        setState(() {
          _myRides = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRides = false;
        });
      }
    }
  }

  void _showRideDetailsDialog(Ride ride) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFFFAF7F4),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5D7C9),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF7E9DF),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: const Icon(Icons.directions_car, color: Color(0xFFFF5A1F), size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ride.carName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2B1B12),
                        ),
                      ),
                      Text(
                        'Booking ID: ${ride.id}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7D6C62),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Color(0xFFE5D7C9)),
            const SizedBox(height: 12),
            _buildRideDetailRow(
              icon: Icons.calendar_today,
              label: 'Rental Start',
              value: ride.startDateTime != null ? _formatDateTime(ride.startDateTime!) : 'Not specified',
              isDark: false,
            ),
            const SizedBox(height: 12),
            _buildRideDetailRow(
              icon: Icons.calendar_today,
              label: 'Rental End',
              value: ride.endDateTime != null ? _formatDateTime(ride.endDateTime!) : 'Not specified',
              isDark: false,
            ),
            const SizedBox(height: 12),
            _buildRideDetailRow(
              icon: Icons.access_time,
              label: 'Rental Type',
              value: _getRentalTypeText(ride.rentalType),
              isDark: false,
            ),
            const SizedBox(height: 12),
            _buildRideDetailRow(
              icon: Icons.currency_rupee,
              label: 'Amount Paid',
              value: '₹${ride.amount.toStringAsFixed(2)}',
              isDark: false,
              isBold: true,
            ),
            if (ride.handoverDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _buildRideDetailRow(
                  icon: Icons.handshake,
                  label: 'Handed Over',
                  value: _formatDateTime(ride.handoverDate!),
                  isDark: false,
                  valueColor: const Color(0xFF2E7D32),
                ),
              ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 4.5),
              decoration: BoxDecoration(
                color: const Color(0xFFCC3F0C),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFCC3F0C).withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFF7A47), Color(0xFFFF5A1F), Color(0xFFE64A12)],
                        stops: [0.0, 0.45, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.35),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'Close',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(
                            color: Color(0x66000000),
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
          ],
        ),
      ),
    );
  }

  Widget _buildRideDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFFF5A1F)),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF7D6C62),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor ?? const Color(0xFF2B1B12),
            ),
          ),
        ),
      ],
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: const Color(0xFFFAF7F4),
        title: const Text(
          'Logout',
          style: TextStyle(color: Color(0xFF2B1B12), fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Color(0xFF7D6C62)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF7D6C62),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('auth_token');
              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.only(bottom: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFFCC3F0C),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFCC3F0C).withOpacity(0.30),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFF7A47), Color(0xFFFF5A1F), Color(0xFFE64A12)],
                    stops: [0.0, 0.45, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.35),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    shadows: [
                      Shadow(
                        color: Color(0x66000000),
                        offset: Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== REDESIGNED UI BUILD METHODS - LIGHT MODE ==========
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFEDE1D5),
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFFEDE1D5),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFFEDE1D5),
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: [
                          _buildHomeTab(),
                          _buildRidesTab(),
                          _buildProfileTab(),
                        ],
                      ),
                    ),
                    // ========== 3D RECTANGULAR CIRCULAR BOTTOM NAVIGATION WITH SLIDING 3D ORANGE BUTTON ==========
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD6C6B8),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          const BoxShadow(
                            color: Color(0x282B1B12),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.only(bottom: 4.5),
                      child: Container(
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFFFFFFF), Color(0xFFFAF7F4), Color(0xFFF3ECE4)],
                            stops: [0.0, 0.45, 1.0],
                          ),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: const Color(0xFFE2D3C4),
                            width: 1.2,
                          ),
                        ),
                        padding: const EdgeInsets.all(5),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final double tabWidth = constraints.maxWidth / 3;
                            return Stack(
                              children: [
                                // Sliding 3D Orange Button with Glow Shadow
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                  left: _selectedIndex * tabWidth,
                                  top: 0,
                                  bottom: 0,
                                  width: tabWidth,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Container(
                                      padding: const EdgeInsets.only(bottom: 3.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFCC3F0C),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFFF5A1F).withOpacity(0.45),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                          const BoxShadow(
                                            color: Color(0x252B1B12),
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [Color(0xFFFF7A47), Color(0xFFFF5A1F), Color(0xFFE64A12)],
                                            stops: [0.0, 0.45, 1.0],
                                          ),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.35),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Interactive Tab Items
                                Row(
                                  children: [
                                    _buildRiderNavTabItem(
                                      index: 0,
                                      label: 'Home',
                                      icon: Icons.home_outlined,
                                      activeIcon: Icons.home,
                                    ),
                                    _buildRiderNavTabItem(
                                      index: 1,
                                      label: 'My Rides',
                                      icon: Icons.directions_car_outlined,
                                      activeIcon: Icons.directions_car,
                                    ),
                                    _buildRiderNavTabItem(
                                      index: 2,
                                      label: 'Profile',
                                      icon: Icons.person_outline,
                                      activeIcon: Icons.person,
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                if (_showFilterMenu)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showFilterMenu = false;
                      });
                    },
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                if (_showFilterMenu)
                  Positioned(
                    top: _getFilterMenuPosition(),
                    right: 20,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 220,
                        constraints: const BoxConstraints(
                          maxHeight: 400,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF7F4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFE5D7C9),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: _filterOptions.map((filter) {
                                return InkWell(
                                  onTap: () {
                                    _filtercars(filter);
                                    _showFilterMenu = false;
                                    String successMessage = '';
                                    if (filter == 'All') {
                                      successMessage = 'Showing all cars';
                                    } else if (filter == 'Sort by Low to High') {
                                      successMessage = 'Sorted by price: Low to High';
                                    } else if (filter == 'Sort by High to Low') {
                                      successMessage = 'Sorted by price: High to Low';
                                    } else {
                                      successMessage = 'Showing: $filter';
                                    }
                                    _showSuccessMessage(successMessage);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Color(0xFFE5D7C9),
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        if (_selectedFilter == filter)
                                          const Icon(
                                            Icons.check_circle,
                                            size: 16,
                                            color: Color(0xFFFF5A1F),
                                          )
                                        else
                                          const SizedBox(width: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            filter,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: _selectedFilter == filter
                                                  ? const Color(0xFFFF5A1F)
                                                  : const Color(0xFF2B1B12),
                                              fontWeight: _selectedFilter == filter
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRiderNavTabItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
  }) {
    final bool isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _selectedIndex = index;
            _showFilterMenu = false;
            if (index == 1) {
              _loadMyRides();
            }
          });
        },
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  key: ValueKey<bool>(isSelected),
                  color: isSelected ? Colors.white : const Color(0xFF7D6C62),
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF7D6C62),
                  shadows: isSelected
                      ? const [
                          Shadow(
                            color: Color(0x66000000),
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _getFilterMenuPosition() {
    final RenderBox? buttonRenderBox = _filterButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (buttonRenderBox != null) {
      final buttonPosition = buttonRenderBox.localToGlobal(Offset.zero);
      return buttonPosition.dy + 45;
    }
    return 180;
  }

  // ========== REDESIGNED HOME TAB - DARK MODE ONLY ==========
  Widget _buildHomeTab() {
    return RefreshIndicator(
      key: _refreshIndicatorKey,
      onRefresh: () async {
        await _requestLocationPermission();
        await _loadcarsFromBackend();
      },
      color: const Color(0xFFFF5A1F),
      child: GestureDetector(
        onTap: () {
          if (_showFilterMenu) {
            setState(() {
              _showFilterMenu = false;
            });
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar and Filter Button
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFD6C6B8),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          const BoxShadow(
                            color: Color(0x202B1B12),
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.only(bottom: 3.5),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFFFFFFF), Color(0xFFFAF7F4), Color(0xFFF3ECE4)],
                            stops: [0.0, 0.45, 1.0],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFE2D3C4),
                            width: 1.2,
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              if (value.isEmpty) {
                                _filtercars(_selectedFilter);
                              } else {
                                _filteredcars = _filteredcars
                                    .where((car) => car['name']
                                    .toLowerCase()
                                    .contains(value.toLowerCase()))
                                    .toList();
                              }
                            });
                          },
                          style: const TextStyle(color: Color(0xFF2B1B12)),
                          decoration: const InputDecoration(
                            hintText: 'Search by brand, model or location',
                            hintStyle: TextStyle(
                              color: Color(0xFF7D6C62),
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Color(0xFF7D6C62),
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    key: _filterButtonKey,
                    padding: const EdgeInsets.only(bottom: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCC3F0C),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFCC3F0C).withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _showFilterMenu = !_showFilterMenu;
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFFF7A47), Color(0xFFFF5A1F), Color(0xFFE64A12)],
                              stops: [0.0, 0.45, 1.0],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.35),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.filter_list,
                                size: 18,
                                color: Colors.white,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Filter',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  shadows: [
                                    Shadow(
                                      color: Color(0x66000000),
                                      offset: Offset(0, 1),
                                      blurRadius: 2,
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
                ],
              ),
              const SizedBox(height: 24),

              // Location Error
              if (_locationError.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7E9DF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFF5A1F),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_off, color: Color(0xFFFF5A1F)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _locationError,
                          style: const TextStyle(color: Color(0xFF2B1B12), fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: _requestLocationPermission,
                        child: const Text('Retry', style: TextStyle(color: Color(0xFFFF5A1F), fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),

              // Nearby Cars Section
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nearby Cars',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2B1B12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _isLoadingcars || _isLoadingLocation
                  ? const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFF5A1F),
                  ),
                ),
              )
                  : _nearbycars.isEmpty
                  ? SizedBox(
                height: 200,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.location_off,
                        size: 48,
                        color: Color(0xFF7D6C62),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentPosition == null
                            ? 'Enable location to see nearby cars'
                            : 'No cars found within 10km radius',
                        style: const TextStyle(
                          color: Color(0xFF7D6C62),
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  : SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _nearbycars.length > 5 ? 5 : _nearbycars.length,
                  itemBuilder: (context, index) {
                    return _buildcarCard(
                      name: _nearbycars[index]['name'],
                      price: _nearbycars[index]['priceText'],
                      distance: '${(_nearbycars[index]['distance'] as double).toStringAsFixed(1)} km',
                      rating: _nearbycars[index]['rating'],
                      carData: _nearbycars[index],
                      isAlternate: index.isOdd,
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Available Cars Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _availablecarsTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2B1B12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _isLoadingcars
                  ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(
                    color: Color(0xFFFF5A1F),
                  ),
                ),
              )
                  : _filteredcars.isEmpty
                  ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.directions_car,
                        size: 64,
                        color: Color(0xFF7D6C62),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No cars available',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF2B1B12),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Check back later for new listings',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF7D6C62),
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredcars.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildAvailablecarCard(
                      carData: _filteredcars[index],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildcarCard({
    required String name,
    required String price,
    required String distance,
    required double rating,
    required Map<String, dynamic> carData,
    bool isAlternate = false,
  }) {
    final Color cardBg = isAlternate ? const Color(0xFFF7E9DF) : const Color(0xFFFAF7F4);
    final Color innerBg = isAlternate ? const Color(0xFFFAF7F4) : const Color(0xFFF7E9DF);

    return GestureDetector(
      onTap: () {
        _showcarDetailPopup(carData);
      },
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFD6C6B8), // 3D depth lip
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            const BoxShadow(
              color: Color(0x222B1B12),
              blurRadius: 6,
              offset: Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.only(bottom: 4.5), // 3D shelf
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFFFFFFF),
                cardBg,
                const Color(0xFFF3ECE4),
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE2D3C4),
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 70,
                decoration: BoxDecoration(
                  color: innerBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: AppIconOrImage(
                    icon: Icons.directions_car,
                    imageUrl: (carData['photos'] is List && (carData['photos'] as List).isNotEmpty)
                        ? (carData['photos'] as List).first.toString()
                        : null,
                    iconColor: const Color(0xFFFF5A1F),
                    size: 35,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B1B12),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.star, size: 11, color: Color(0xFFFF5A1F)),
                  const SizedBox(width: 3),
                  Text(
                    rating.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF2B1B12), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.location_on, size: 11, color: Color(0xFF7D6C62)),
                  const SizedBox(width: 3),
                  Text(
                    distance,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF7D6C62)),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              if (_getOfferText(carData['offer']).isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5A1F),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getOfferText(carData['offer']),
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Text(
                price,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B1B12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvailablecarCard({
    required Map<String, dynamic> carData,
  }) {
    return GestureDetector(
      onTap: () {
        _showcarDetailPopup(carData);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFD6C6B8), // 3D depth lip
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            const BoxShadow(
              color: Color(0x222B1B12),
              blurRadius: 6,
              offset: Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.only(bottom: 4.5), // 3D shelf
        child: Container(
          padding: const EdgeInsets.all(12),
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
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE2D3C4),
              width: 1.2,
            ),
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
              child: Center(
                child: AppIconOrImage(
                  icon: Icons.directions_car,
                  imageUrl: (carData['photos'] is List && (carData['photos'] as List).isNotEmpty)
                      ? (carData['photos'] as List).first.toString()
                      : null,
                  iconColor: const Color(0xFFFF5A1F),
                  size: 30,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    carData['name'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2B1B12),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: Color(0xFFFF5A1F)),
                      const SizedBox(width: 4),
                      Text(
                        carData['rating'].toStringAsFixed(1),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2B1B12)),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.location_on, size: 12, color: Color(0xFF7D6C62)),
                      const SizedBox(width: 4),
                      Text(
                        '${(carData['distance'] as double).toStringAsFixed(1)} km',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF7D6C62)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_getOfferText(carData['offer']).isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5A1F),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _getOfferText(carData['offer']),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Text(
                  carData['priceText'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B1B12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildRidesTab() {
    if (_isLoadingRides) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF5A1F)),
      );
    }

    if (_myRides.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFFF5A1F),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5A1F).withOpacity(0.25),
                    blurRadius: 20,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: const Icon(Icons.directions_car, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Active Rides',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B1B12),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Book a car to start your journey',
              style: TextStyle(color: Color(0xFF7D6C62)),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.only(bottom: 4.5),
              decoration: BoxDecoration(
                color: const Color(0xFFCC3F0C),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFCC3F0C).withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedIndex = 0;
                    });
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFF7A47), Color(0xFFFF5A1F), Color(0xFFE64A12)],
                        stops: [0.0, 0.45, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.35),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'Find a Car',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Color(0x66000000),
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
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyRides,
      color: const Color(0xFFFF5A1F),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myRides.length,
        itemBuilder: (context, index) {
          final ride = _myRides[index];

          bool isOngoing = ride.handoverDate == null && ride.status != 'completed' && ride.status != 'cancelled';

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: isOngoing ? const Color(0xFFCC3F0C) : const Color(0xFFD6C6B8),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: isOngoing
                      ? const Color(0xFFCC3F0C).withOpacity(0.35)
                      : const Color(0x222B1B12),
                  blurRadius: isOngoing ? 10 : 6,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.only(bottom: 4.5),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFFFFF), Color(0xFFFAF7F4), Color(0xFFF3ECE4)],
                  stops: [0.0, 0.45, 1.0],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isOngoing ? const Color(0xFFFF5A1F) : const Color(0xFFE2D3C4),
                  width: isOngoing ? 1.6 : 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7E9DF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.directions_car, color: Color(0xFFFF5A1F), size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ride.carName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2B1B12),
                              ),
                            ),
                            Text(
                              'Booking ID: ${ride.id.substring(0, 8)}...',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7D6C62),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOngoing
                              ? const Color(0xFFFF5A1F)
                              : (ride.status == 'completed'
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFF7D6C62)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isOngoing ? 'ONGOING' : (ride.status == 'completed' ? 'COMPLETED' : ride.status.toUpperCase()),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(
                    color: Color(0xFFE5D7C9),
                    height: 1,
                  ),
                  const SizedBox(height: 8),

                  if (ride.startDateTime != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 14, color: Color(0xFF7D6C62)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Rented: ${_formatDateTime(ride.startDateTime!)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7D6C62),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (ride.handoverDate != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.handshake, size: 14, color: Color(0xFF2E7D32)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Handed Over: ${_formatDateTime(ride.handoverDate!)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 14, color: Color(0xFF7D6C62)),
                          const SizedBox(width: 4),
                          Text(
                            _getRentalTypeText(ride.rentalType),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF7D6C62),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '₹${ride.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF5A1F),
                        ),
                      ),
                    ],
                  ),

                  if (isOngoing)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.only(bottom: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCC3F0C),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFCC3F0C).withOpacity(0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              _showRideDetailsDialog(ride);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Color(0xFFFF7A47), Color(0xFFFF5A1F), Color(0xFFE64A12)],
                                  stops: [0.0, 0.45, 1.0],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.35),
                                  width: 1,
                                ),
                              ),
                              child: const Text(
                                'View Ride Details',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  shadows: [
                                    Shadow(
                                      color: Color(0x66000000),
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F4),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE5D7C9), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.person,
              color: Color(0xFFFF5A1F),
              size: 50,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.userData['fullname'] ?? 'Rider',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2B1B12),
            ),
          ),
          Text(
            widget.userData['email'] ?? 'rider@example.com',
            style: const TextStyle(color: Color(0xFF7D6C62)),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RiderPersonalInformation(
                    userData: widget.userData,
                    isDarkMode: false,
                  ),
                ),
              );
            },
            child: _buildProfileOption(
              icon: Icons.person_outline,
              title: 'Personal Information',
              subtitle: 'Update your personal details',
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RiderHelpSupport(
                    isDarkMode: false,
                  ),
                ),
              );
            },
            child: _buildProfileOption(
              icon: Icons.help_outline,
              title: 'Help & Support',
              subtitle: 'Get assistance with your rides',
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AboutcarrzzRiders(
                    isDarkMode: false,
                  ),
                ),
              );
            },
            child: _buildProfileOption(
              icon: Icons.info_outline,
              title: 'About Carzzz',
              subtitle: 'Learn more about our car rental services',
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 4.5),
            decoration: BoxDecoration(
              color: const Color(0xFFCC3F0C),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFCC3F0C).withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _showLogoutDialog();
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFF7A47), Color(0xFFFF5A1F), Color(0xFFE64A12)],
                      stops: [0.0, 0.45, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.35),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'Logout',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Color(0x66000000),
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
        ],
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFD6C6B8),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          const BoxShadow(
            color: Color(0x202B1B12),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.only(bottom: 3.5),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFFAF7F4), Color(0xFFF3ECE4)],
            stops: [0.0, 0.45, 1.0],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE2D3C4),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7E9DF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFFFF5A1F), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2B1B12),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF7D6C62)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF7D6C62)),
          ],
        ),
      ),
    );
  }
}