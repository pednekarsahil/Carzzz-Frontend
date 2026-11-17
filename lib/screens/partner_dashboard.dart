
// ============================================================
// FILE: partner_dashboard.dart
// PURPOSE: Main partner dashboard with fleet management
//
// DETAILS:
// - Displays 4 tabs: Dashboard, My Cars, Earnings, Locations
// - Real-time car status updates via Socket.io WebSocket
// - Auto-refresh dashboard stats every 30 seconds
// - Full CRUD operations for car inventory (Add/Edit/Delete)
// - Interactive map with color-coded car markers
// - Token-based authentication with auto-logout on expiry
// - Recent activity feed tracking business actions
// - Earnings breakdown with visual progress bars
// - Responsive dark theme UI with gradient styling
//
// DEPENDENCIES:
// - flutter_map, latlong2 for map functionality
// - socket_io_client for real-time updates
// - http, shared_preferences, intl, dart:convert
//
// NAVIGATION:
// - Add Car → PartnerAddNewcar
// - Edit Car → PartnerEditcar
// - Logout → Clears token and returns to login
//
// STATE MANAGEMENT:
// - SingleTickerProviderStateMixin for animations
// - Timer-based auto-refresh (30 seconds)
// - Manual pull-to-refresh on Dashboard & My Cars
// ============================================================





/*



FILE: partner_dashboard.dart
PURPOSE: Partner dashboard for managing cars and business with real-time updates
*/

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'partner_addnewcarbutton.dart';
import 'partner_editcar.dart';
import '../widgets/app_icon_or_image.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class PartnerDashboard extends StatefulWidget {
  final Map<String, dynamic> partnerData;

  const PartnerDashboard({
    super.key,
    required this.partnerData,
  });

  @override
  State<PartnerDashboard> createState() => _PartnerDashboardState();
}

class _PartnerDashboardState extends State<PartnerDashboard> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _cars = [];
  bool _isLoading = true;
  late TabController _tabController;

  // Refresh indicators keys
  final GlobalKey<RefreshIndicatorState> _dashboardRefreshKey = GlobalKey<RefreshIndicatorState>();
  final GlobalKey<RefreshIndicatorState> _carsRefreshKey = GlobalKey<RefreshIndicatorState>();

  // Timer for auto-refresh
  Timer? _autoRefreshTimer;

  // Recent activities list
  final List<Map<String, dynamic>> _recentActivities = [];
  double? _lastServerEarnings;
  double? _cachedLastTotalEarnings;
  double _socketCreditedSinceLastPoll = 0.0;
  String _currentEarningsDate = '';
  final Set<String> _processedPaymentIds = {};
  final Map<String, DateTime> _recentPaymentSignatures = {};

  // API Base URL
  static const int _connectionTimeout = 30;
  static const int _autoRefreshInterval = 30;
  static const bool _usePhysicalDevice = false;

  String get _baseUrl {
    if (_usePhysicalDevice) {
      return 'http://10.0.2.2:3000';
    } else {
      return 'https://carzzz-frontend.onrender.com';
    }
  }

  // Stats
  int _totalcars = 0;
  int _availablecars = 0;
  int _rentedcars = 0;
  int _maintenancecars = 0;
  double _totalEarnings = 0.0;
  double _todayEarnings = 0.0;
  int _activeViews = 0;

  // Socket.io instance
  IO.Socket? _socket;

  // Transactions data
  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];

  // Date filter
  DateTime? _selectedFromDate;
  DateTime? _selectedToDate;
  String _transactionsHeading = 'Recent Transactions';

  // FlutterMap
  final MapController _mapController = MapController();
  final List<Marker> _flutterMarkers = [];
  static const LatLng _initialPosition = LatLng(28.6139, 77.2090);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currentEarningsDate = _getDateKey(DateTime.now());
    _totalEarnings = _parseDouble(widget.partnerData['totalEarnings']) ?? 0.0;
    _todayEarnings = _parseDouble(
          widget.partnerData['todayEarnings'] ?? widget.partnerData['todaysEarnings'],
        ) ??
        0.0;
    _checkTokenAndLoadData();
    _loadTransactions();
    _startActiveViewsSimulation();
    _startAutoRefresh();
  }

  // Check token and load data
  Future<void> _checkTokenAndLoadData() async {
    await _loadCachedEarnings();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('partner_token');

    print('🔑 Token check - exists: ${token != null}, length: ${token?.length ?? 0}');

    if (token == null || token.isEmpty) {
      print('❌ No token found, redirecting to login');
      _showLoginRequiredDialog();
      return;
    }

    // Verify token with backend first
    final isValid = await _verifyTokenWithBackend(token);
    if (!isValid) {
      print('❌ Token verification failed - clearing token');
      await prefs.remove('partner_token');
      await prefs.remove('partner_data');
      _showLoginRequiredDialog();
      return;
    }

    // Load dashboard data
    await _loadcarsFromAPI();
  }

  // Verify token with backend
  Future<bool> _verifyTokenWithBackend(String token) async {
    try {
      print('🔍 Verifying token with backend...');
      final response = await http.post(
        Uri.parse('$_baseUrl/api/partner/verify-token'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('📡 Token verification status: ${response.statusCode}');
      print('📡 Token verification response: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['valid'] == true || data['success'] == true;
      } else {
        print('❌ Token verification failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error verifying token: $e');
      return false;
    }
  }

  // Start auto-refresh timer
  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: _autoRefreshInterval),
          (timer) {
        if (mounted && (_selectedIndex == 0 || _selectedIndex == 2)) {
          _refreshDashboardStats();
        }
      },
    );
  }

// Initialize Socket with authentication - FIXED VERSION
  void _initSocket(String token) {
    try {
      print('🔌 Initializing socket with token...');
      print('📝 Token length: ${token.length}');

      // Create socket with proper configuration
      // The server now accepts all connections, authentication happens via partner_join
      _socket = IO.io(_baseUrl, <String, dynamic>{
        'transports': ['polling', 'websocket'],
        'autoConnect': true,
        'path': '/socket.io',
        'query': {
          'token': token,
          'role': 'partner'
        },
        'extraHeaders': {
          'Authorization': 'Bearer $token'
        },
        'reconnection': true,
        'reconnectionAttempts': 3,
        'reconnectionDelay': 2000,
        'reconnectionDelayMax': 5000,
        'timeout': 10000,
        'forceNew': true,
      });

      _socket!.onConnect((_) {
        print('✅ Partner socket connected successfully');

        // Send partner_join event after connection with token
        final partnerId = widget.partnerData['id'];
        if (partnerId != null) {
          _socket?.emit('partner_join', {
            'partnerId': partnerId,
            'businessName': widget.partnerData['businessName'] ?? 'My Business',
            'token': token,  // Send token for authentication
          });
          print('📡 Sent partner_join event for: $partnerId');
        }
      });

      _socket!.onConnectError((error) {
        print('❌ Socket connection error: $error');
        // The reconnection will be handled by the reconnection options
      });

      _socket!.on('partner_joined', (dynamic data) {
        print('✅ Partner joined room successfully: $data');
      });

      _socket!.on('car_rented', (dynamic data) {
        print('📱 Car rented: ${data['carId']}');
        _updatecarStatus(data['carId'], 'rented');
        _handleSocketPayment(data);
        _showSnackBar('Your Car "${data['carModel']}" has been rented!', const Color(0xFF10B981));
      });

      _socket!.on('payment_received', (dynamic data) {
        print('💰 Payment received event: $data');
        _handleSocketPayment(data);
      });

      _socket!.on('earnings_updated', (dynamic data) {
        print('💰 Earnings updated event: $data');
        _handleSocketPayment(data);
      });

      _socket!.on('car_status_updated', (dynamic data) {
        print('📱 Car status updated: ${data['carId']} -> ${data['status']}');
        _updatecarStatus(data['carId'], data['status']);
      });

      _socket!.on('error', (data) {
        print('❌ Socket error: $data');
      });

      _socket!.onDisconnect((_) {
        print('🔌 Partner socket disconnected');
      });

      // Connect
      print('🔄 Connecting socket to: $_baseUrl');
      _socket?.connect();

    } catch (e) {
      print('Error initializing partner socket: $e');
    }
  }

  void _updatecarStatus(String carId, String newStatus) {
    setState(() {
      final carIndex = _cars.indexWhere((car) => car['id'] == carId);
      if (carIndex != -1) {
        _cars[carIndex]['status'] = newStatus;
        _updateStatsAfterAdd();
        _initMarkers();
      }
    });
  }

  // Manual refresh for dashboard
  Future<void> _manualRefresh() async {
    await _loadcarsFromAPI();
    await _refreshDashboardStats();
  }

  // Refresh dashboard stats from backend
  Future<void> _refreshDashboardStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('partner_token');

      if (token == null || token.isEmpty) {
        print('❌ No token for dashboard stats refresh');
        return;
      }

      print('🔄 Refreshing dashboard stats...');

      final response = await http.get(
        Uri.parse('$_baseUrl/api/partner/dashboard'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: _connectionTimeout));

      print('📡 Stats refresh status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📡 Stats response: ${response.body.substring(0, 100)}...');

        if (data['success'] == true && data['data'] != null) {
          final stats = data['data']['stats'];
          final carsData = data['data']['cars'];
          if (mounted) {
            setState(() {
              _totalcars = stats['totalcars'] ?? _totalcars;
              _availablecars = stats['availablecars'] ?? _availablecars;
              _rentedcars = stats['rentedcars'] ?? _rentedcars;
              _maintenancecars = stats['maintenancecars'] ?? _maintenancecars;

              if (carsData is List) {
                _cars = carsData.map((car) => {
                  'id': car['id'],
                  'model': car['model'],
                  'type': car['type'],
                  'fuelType': car['fuelType'],
                  'dailyRate': car['dailyRate'],
                  'status': car['status'],
                  'rating': car['rating']?.toDouble() ?? 0.0,
                  'reviewCount': car['reviewCount'] ?? 0,
                  'location': car['location'],
                  'images': car['images'] ?? [],
                  'description': car['description'] ?? '',
                  'offer': car['offer'],
                }).toList();
              }
            });
            if (data['data'] is Map) {
              _updateEarningsFromServer(Map<String, dynamic>.from(data['data'] as Map));
            }
          }
        }
      } else if (response.statusCode == 401) {
        print('❌ Unauthorized - Token invalid in stats refresh');
        await prefs.remove('partner_token');
        await prefs.remove('partner_data');
        if (mounted) {
          _showLoginRequiredDialog();
        }
      }
    } catch (e) {
      print('Error refreshing dashboard stats: $e');
    }
  }

  // Load cars from backend API with retry logic
  Future<void> _loadcarsFromAPI({int retryCount = 0}) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('partner_token');

      if (token == null || token.isEmpty) {
        print('❌ No token found in _loadcarsFromAPI');
        setState(() {
          _cars = [];
          _totalcars = 0;
          _availablecars = 0;
          _rentedcars = 0;
          _maintenancecars = 0;
          _isLoading = false;
        });
        _showLoginRequiredDialog();
        return;
      }

      // Initialize socket with token
      _initSocket(token);

      print('📡 Fetching dashboard data...');

      final response = await http.get(
        Uri.parse('$_baseUrl/api/partner/dashboard'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: _connectionTimeout));

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final carsData = data['data']['cars'] as List;
          _cars = carsData.map((car) => {
            'id': car['id'],
            'model': car['model'],
            'type': car['type'],
            'fuelType': car['fuelType'],
            'dailyRate': car['dailyRate'],
            'status': car['status'],
            'rating': car['rating']?.toDouble() ?? 0.0,
            'reviewCount': car['reviewCount'] ?? 0,
            'location': car['location'],
            'images': car['images'] ?? [],
            'description': car['description'] ?? '',
            'offer': car['offer'],
          }).toList();

          final stats = data['data']['stats'];
          _totalcars = stats['totalcars'] ?? _cars.length;
          _availablecars = stats['availablecars'] ?? _cars.where((b) => b['status'] == 'available').length;
          _rentedcars = stats['rentedcars'] ?? _cars.where((b) => b['status'] == 'rented').length;
          _maintenancecars = stats['maintenancecars'] ?? _cars.where((b) => b['status'] == 'maintenance').length;

          if (data['data'] is Map) {
            _updateEarningsFromServer(Map<String, dynamic>.from(data['data'] as Map));
          }

          print('✅ Loaded ${_cars.length} cars successfully');
        } else {
          print('❌ API returned success: false or no data');
          setState(() {
            _cars = [];
            _totalcars = 0;
            _availablecars = 0;
            _rentedcars = 0;
            _maintenancecars = 0;
          });
        }
      } else if (response.statusCode == 401) {
        print('❌ Unauthorized - Token invalid or expired');
        await prefs.remove('partner_token');
        await prefs.remove('partner_data');
        _showLoginRequiredDialog();
        setState(() {
          _cars = [];
          _totalcars = 0;
          _availablecars = 0;
          _rentedcars = 0;
          _maintenancecars = 0;
          _isLoading = false;
        });
        return;
      } else {
        print('❌ API error: ${response.statusCode} - ${response.body}');
        setState(() {
          _cars = [];
          _totalcars = 0;
          _availablecars = 0;
          _rentedcars = 0;
          _maintenancecars = 0;
        });
      }
    } catch (e) {
      print('❌ Error loading cars from API: $e');
      if (retryCount < 2) {
        print('🔄 Retrying... (${retryCount + 1}/2)');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          await _loadcarsFromAPI(retryCount: retryCount + 1);
        }
      } else {
        print('❌ Failed after 3 attempts');
        setState(() {
          _cars = [];
          _totalcars = 0;
          _availablecars = 0;
          _rentedcars = 0;
          _maintenancecars = 0;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _initMarkers();
      }
    }
  }

  void _loadTransactions() {
    _allTransactions = [
      {
        'customer': 'Rajesh Kumar',
        'car': 'Honda Activa 125',
        'amount': 199.0,
        'date': DateTime(2026, 3, 25),
        'time': '10:30 AM',
      },
      {
        'customer': 'Priya Sharma',
        'car': 'TVS Jupiter',
        'amount': 358.0,
        'date': DateTime(2026, 3, 25),
        'time': '9:15 AM',
      },
      {
        'customer': 'Amit Singh',
        'car': 'Yamaha Fascino',
        'amount': 189.0,
        'date': DateTime(2026, 3, 24),
        'time': '6:45 PM',
      },
    ];

    _filteredTransactions = List.from(_allTransactions);
  }

  String _getDateKey(DateTime dt) {
    final String month = dt.month.toString().padLeft(2, '0');
    final String day = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$month-$day';
  }

  String get _earningsCacheKey =>
      'partner_earnings_cache_${widget.partnerData['id'] ?? 'default'}';

  double? _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  void _rolloverTodayIfNeeded() {
    final String todayKey = _getDateKey(DateTime.now());
    if (_currentEarningsDate != todayKey) {
      _currentEarningsDate = todayKey;
      _todayEarnings = 0.0;
      _cachedLastTotalEarnings = null;
    }
  }

  Future<void> _loadCachedEarnings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_earningsCacheKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = json.decode(raw);
      if (decoded is! Map) return;
      final String todayKey = _getDateKey(DateTime.now());
      if (decoded['date'] == todayKey && mounted) {
        setState(() {
          _currentEarningsDate = todayKey;
          _todayEarnings = _parseDouble(decoded['todayEarnings']) ?? _todayEarnings;
          _cachedLastTotalEarnings = _parseDouble(decoded['lastTotalEarnings']);
        });
      }
    } catch (e) {
      print('Error loading cached earnings: $e');
    }
  }

  Future<void> _saveCachedEarnings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _earningsCacheKey,
        json.encode({
          'date': _currentEarningsDate.isNotEmpty
              ? _currentEarningsDate
              : _getDateKey(DateTime.now()),
          'todayEarnings': _todayEarnings,
          'lastTotalEarnings': _totalEarnings,
        }),
      );
    } catch (e) {
      print('Error saving cached earnings: $e');
    }
  }

  double? _computeTodayEarningsFromList(List items) {
    final DateTime now = DateTime.now();
    double sum = 0.0;
    for (final item in items) {
      if (item is! Map) continue;
      final String status = (item['status'] ?? '').toString().toLowerCase();
      if (status == 'cancelled' || status == 'failed' || status == 'refunded') {
        continue;
      }
      final dynamic rawDate =
          item['createdAt'] ?? item['bookingDate'] ?? item['paidAt'] ?? item['date'];
      if (rawDate == null) continue;
      final DateTime? dt = DateTime.tryParse(rawDate.toString())?.toLocal();
      if (dt != null && dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        final double? amt = _parseDouble(
          item['partnerEarning'] ??
              item['earning'] ??
              item['amount'] ??
              item['totalAmount'] ??
              item['paidAmount'],
        );
        if (amt != null && amt > 0) {
          sum += amt;
        }
      }
    }
    return sum;
  }

  void _handleSocketPayment(dynamic data) {
    if (data is! Map) return;
    _rolloverTodayIfNeeded();

    final Map payload = data;
    final Map? partnerMap = payload['partner'] is Map ? payload['partner'] as Map : null;
    final double? amount = _parseDouble(
      payload['amount'] ??
          payload['totalAmount'] ??
          payload['paidAmount'] ??
          payload['earning'] ??
          payload['partnerEarning'],
    );
    final double? payloadTotal = _parseDouble(
      payload['totalEarnings'] ?? partnerMap?['totalEarnings'],
    );
    final double? payloadToday = _parseDouble(
      payload['todayEarnings'] ??
          payload['todaysEarnings'] ??
          partnerMap?['todayEarnings'] ??
          partnerMap?['todaysEarnings'],
    );

    final String? txId = (payload['paymentId'] ??
            payload['razorpayOrderId'] ??
            payload['orderId'] ??
            payload['bookingId'] ??
            payload['transactionId'])
        ?.toString();
    if (txId != null && txId.isNotEmpty) {
      if (_processedPaymentIds.contains(txId)) return;
      _processedPaymentIds.add(txId);
    } else if (amount != null && amount > 0) {
      final String sig = '${payload['carId'] ?? ''}_${amount.toStringAsFixed(2)}';
      final DateTime now = DateTime.now();
      final DateTime? prev = _recentPaymentSignatures[sig];
      if (prev != null && now.difference(prev).inSeconds < 5) return;
      _recentPaymentSignatures[sig] = now;
    }

    final bool hasPositiveAmount = amount != null && amount > 0;
    if (!hasPositiveAmount && payloadTotal == null && payloadToday == null) return;

    if (mounted) {
      setState(() {
        if (payloadTotal != null) {
          _totalEarnings = payloadTotal;
          _lastServerEarnings = payloadTotal;
          _socketCreditedSinceLastPoll = 0.0;
        } else if (hasPositiveAmount) {
          _totalEarnings += amount;
          _socketCreditedSinceLastPoll += amount;
        }

        if (payloadToday != null) {
          _todayEarnings = payloadToday;
        } else if (hasPositiveAmount) {
          _todayEarnings += amount;
        }
      });
    }

    _saveCachedEarnings();
    if (hasPositiveAmount) {
      _recordPaymentActivity(
        amount: amount,
        fromName: payload['riderName']?.toString() ?? payload['userName']?.toString(),
        carModel: payload['carModel']?.toString(),
      );
    }
  }

  void _updateEarningsFromServer(Map<String, dynamic> responseData) {
    _rolloverTodayIfNeeded();
    final Map? stats = responseData['stats'] is Map ? responseData['stats'] as Map : null;
    final Map? partnerInfo = responseData['partner'] is Map ? responseData['partner'] as Map : null;
    final Map? earningsMap = responseData['earnings'] is Map ? responseData['earnings'] as Map : null;

    final double? serverTotalEarnings = _parseDouble(
      partnerInfo?['totalEarnings'] ??
          stats?['totalEarnings'] ??
          responseData['totalEarnings'] ??
          earningsMap?['totalEarnings'] ??
          earningsMap?['total'],
    );

    double? serverTodayEarnings = _parseDouble(
      partnerInfo?['todayEarnings'] ??
          partnerInfo?['todaysEarnings'] ??
          stats?['todayEarnings'] ??
          stats?['todaysEarnings'] ??
          responseData['todayEarnings'] ??
          responseData['todaysEarnings'] ??
          earningsMap?['todayEarnings'] ??
          earningsMap?['today'],
    );

    if (serverTodayEarnings == null) {
      final dynamic listCandidate =
          responseData['bookings'] ?? responseData['transactions'] ?? responseData['orders'];
      if (listCandidate is List) {
        serverTodayEarnings = _computeTodayEarningsFromList(listCandidate);
      }
    }

    double? newPaymentToRecord;
    if (mounted) {
      setState(() {
        if (serverTotalEarnings != null) {
          if (_lastServerEarnings == null) {
            double offlineDelta = 0.0;
            if (_cachedLastTotalEarnings != null &&
                serverTotalEarnings > _cachedLastTotalEarnings!) {
              offlineDelta = serverTotalEarnings - _cachedLastTotalEarnings!;
            }
            _cachedLastTotalEarnings = null;
            _lastServerEarnings = serverTotalEarnings;
            _socketCreditedSinceLastPoll = 0.0;
            _totalEarnings = serverTotalEarnings;
            if (serverTodayEarnings != null) {
              _todayEarnings = serverTodayEarnings;
            } else if (offlineDelta > 0) {
              _todayEarnings += offlineDelta;
            }
          } else {
            final double serverDelta = serverTotalEarnings - _lastServerEarnings!;
            final double uncreditedDelta = serverDelta - _socketCreditedSinceLastPoll;
            _lastServerEarnings = serverTotalEarnings;
            _socketCreditedSinceLastPoll = 0.0;
            _totalEarnings = serverTotalEarnings;
            if (serverTodayEarnings != null) {
              _todayEarnings = serverTodayEarnings;
            } else if (uncreditedDelta > 0) {
              _todayEarnings += uncreditedDelta;
            }
            if (uncreditedDelta > 0) {
              newPaymentToRecord = uncreditedDelta;
            }
          }
        } else if (serverTodayEarnings != null) {
          _todayEarnings = serverTodayEarnings;
        }
      });
    }

    if (newPaymentToRecord != null) {
      _recordPaymentActivity(amount: newPaymentToRecord!);
    }
    _saveCachedEarnings();
  }

  void _recordPaymentActivity({
    required double amount,
    String? fromName,
    String? carModel,
  }) {
    final String subtitle = fromName != null && fromName.isNotEmpty
        ? '₹${amount.toStringAsFixed(0)} from $fromName'
        : (carModel != null && carModel.isNotEmpty
            ? '₹${amount.toStringAsFixed(0)} for $carModel'
            : '₹${amount.toStringAsFixed(0)} received');

    final activity = {
      'icon': Icons.payments,
      'title': 'Payment Received',
      'subtitle': subtitle,
      'time': 'Just now',
      'color': const Color(0xFFFF5A1F),
    };

    if (!mounted) return;
    setState(() {
      _recentActivities.insert(0, activity);
      if (_recentActivities.length > 10) {
        _recentActivities.removeLast();
      }
    });
  }

  void _addRecentActivity(Map<String, dynamic> car, String action) {
    final activity = {
      'icon': Icons.add_circle,
      'title': action == 'add' ? 'New Car Added' : 'car Updated',
      'subtitle': '${car['model']} - ₹${car['dailyRate']}/day',
      'time': 'Just now',
      'color': const Color(0xFF3B82F6),
    };

    setState(() {
      _recentActivities.insert(0, activity);
      if (_recentActivities.length > 10) {
        _recentActivities.removeLast();
      }
    });

    _showSnackBar('New car "${car['model']}" added to your fleet!', const Color(0xFF10B981));
  }

  void _navigateToAddcarScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PartnerAddNewcar(),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _cars.add(result);
        _updateStatsAfterAdd();
        _addRecentActivity(result, 'add');
      });

      _initMarkers();
      _loadcarsFromAPI();
    }
  }

  void _updateStatsAfterAdd() {
    _totalcars = _cars.length;
    _availablecars = _cars.where((b) => b['status'] == 'available').length;
    _rentedcars = _cars.where((b) => b['status'] == 'rented').length;
    _maintenancecars = _cars.where((b) => b['status'] == 'maintenance').length;
  }

  void _startActiveViewsSimulation() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _activeViews = 8;
        });
      }
    });
  }

  void _initMarkers() {
    _flutterMarkers.clear();
    for (var car in _cars) {
      final lat = car['location']['lat'] as double;
      final lng = car['location']['lng'] as double;

      Color markerColor;
      switch (car['status']) {
        case 'available':
          markerColor = Colors.green;
          break;
        case 'rented':
          markerColor = Colors.red;
          break;
        case 'maintenance':
          markerColor = Colors.orange;
          break;
        default:
          markerColor = Colors.blue;
      }

      final marker = Marker(
        point: LatLng(lat, lng),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showcarDetailsBottomSheet(car),
          child: Container(
            decoration: BoxDecoration(
              color: markerColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.directions_car,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      );

      _flutterMarkers.add(marker);
    }
    setState(() {});
  }

  void _applyDateFilter() {
    if (_selectedFromDate != null && _selectedToDate != null) {
      setState(() {
        _filteredTransactions = _allTransactions.where((transaction) {
          final transactionDate = transaction['date'] as DateTime;
          return transactionDate.isAfter(_selectedFromDate!.subtract(const Duration(days: 1))) &&
              transactionDate.isBefore(_selectedToDate!.add(const Duration(days: 1)));
        }).toList();

        final DateFormat formatter = DateFormat('dd MMM yyyy');
        _transactionsHeading = 'Transactions from ${formatter.format(_selectedFromDate!)} to ${formatter.format(_selectedToDate!)}';
      });
    }
  }

  void _resetDateFilter() {
    setState(() {
      _selectedFromDate = null;
      _selectedToDate = null;
      _filteredTransactions = List.from(_allTransactions);
      _transactionsHeading = 'Recent Transactions';
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabController.dispose();
    _mapController.dispose();
    _socket?.disconnect();
    super.dispose();
  }

  // ========== DIALOGS ==========

  void _showLoginRequiredDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: const Color(0xFFFAF7F4),
        title: const Text(
          'Session Expired',
          style: TextStyle(color: Color(0xFF2B1B12), fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Your session has expired. Please login again to continue.',
          style: TextStyle(color: Color(0xFF7D6C62)),
        ),
        actions: [
          Container(
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
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  // Pop all the way back to login
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                borderRadius: BorderRadius.circular(10),
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
                    'Login Again',
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
          ),
        ],
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
          child: Column(
            children: [
              // Main Content
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    _buildDashboardTab(),
                    _buildcarsTab(),
                    _buildEarningsTab(),
                    _buildLocationTab(),
                  ],
                ),
              ),

              // Bottom Navigation
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: BottomNavigationBar(
                    currentIndex: _selectedIndex,
                    onTap: (index) {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    type: BottomNavigationBarType.fixed,
                    selectedItemColor: const Color(0xFFFF5A1F),
                    unselectedItemColor: const Color(0xFF7D6C62),
                    backgroundColor: Colors.transparent,
                    selectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 12,
                    ),
                    elevation: 0,
                    items: [
                      _buildNavItem(
                        icon: Icons.dashboard_outlined,
                        activeIcon: Icons.dashboard,
                        label: 'Dashboard',
                      ),
                      _buildNavItem(
                        icon: Icons.directions_car_outlined,
                        activeIcon: Icons.directions_car,
                        label: 'My Cars',
                      ),
                      _buildNavItem(
                        icon: Icons.monetization_on_outlined,
                        activeIcon: Icons.monetization_on,
                        label: 'Earnings',
                      ),
                      _buildNavItem(
                        icon: Icons.location_on_outlined,
                        activeIcon: Icons.location_on,
                        label: 'Locations',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  BottomNavigationBarItem _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    String? imageAsset,
    String? activeImageAsset,
    double? iconSize,
    double? scale,
    double? offsetX,
    double? offsetY,
  }) {
    return BottomNavigationBarItem(
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: AppIconOrImage(
          icon: icon,
          imageAsset: imageAsset,
          size: iconSize ?? 24,
          scale: scale ?? 1.0,
          offsetX: offsetX ?? 0.0,
          offsetY: offsetY ?? 0.0,
        ),
      ),
      activeIcon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF7E9DF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: AppIconOrImage(
          icon: activeIcon,
          imageAsset: activeImageAsset ?? imageAsset,
          size: iconSize ?? 24,
          scale: scale ?? 1.0,
          offsetX: offsetX ?? 0.0,
          offsetY: offsetY ?? 0.0,
        ),
      ),
      label: label,
    );
  }

  // ========== DASHBOARD TAB ==========
  Widget _buildDashboardTab() {
    return RefreshIndicator(
      key: _dashboardRefreshKey,
      onRefresh: _manualRefresh,
      color: const Color(0xFFFF5A1F),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                _buildStatCard(
                  title: 'Total Earnings',
                  value: '₹${_totalEarnings.toStringAsFixed(0)}',
                  icon: Icons.wallet,
                  color: const Color(0xFFFF5A1F),
                ),
                _buildStatCard(
                  title: "Today's Earnings",
                  value: '₹${_todayEarnings.toStringAsFixed(0)}',
                  icon: Icons.today,
                  color: const Color(0xFF2E7D32),
                ),
                _buildStatCard(
                  title: 'Total Car',
                  value: '$_totalcars',
                  icon: Icons.directions_car,
                  color: const Color(0xFFD97736),
                ),
                _buildStatCard(
                  title: 'Active Views',
                  value: '$_activeViews',
                  icon: Icons.visibility,
                  color: const Color(0xFF2B1B12),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Car Status
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFD6C6B8),
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
                    color: const Color(0xFFE2D3C4),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Car Status',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2B1B12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildStatusIndicator(
                          color: const Color(0xFF2E7D32),
                          label: 'Available',
                          count: _availablecars,
                        ),
                        _buildStatusIndicator(
                          color: const Color(0xFFD32F2F),
                          label: 'Rented',
                          count: _rentedcars,
                        ),
                        _buildStatusIndicator(
                          color: const Color(0xFFFF5A1F),
                          label: 'Maintenance',
                          count: _maintenancecars,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Recent Activity
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFD6C6B8),
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
                    color: const Color(0xFFE2D3C4),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2B1B12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        final List<Map<String, dynamic>> maintenanceCars = _cars
                            .where((car) => car['status'] == 'maintenance')
                            .toList();

                        final List<Map<String, dynamic>> liveItems = [
                          ..._recentActivities,
                          ...maintenanceCars.map((car) => {
                            'icon': Icons.build,
                            'title': 'Car in Maintenance',
                            'subtitle': '${car['model'] ?? 'Car'}',
                            'time': 'Active',
                            'color': const Color(0xFFD97736),
                          }),
                        ];

                        if (liveItems.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Icon(Icons.history, color: Color(0xFF7D6C62), size: 20),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'No recent activity yet. Payments and maintenance updates will appear here in real time.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF7D6C62),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          children: List.generate(liveItems.length, (index) {
                            final activity = liveItems[index];
                            return Column(
                              children: [
                                _buildActivityItem(
                                  icon: activity['icon'] as IconData,
                                  title: activity['title'].toString(),
                                  subtitle: activity['subtitle'].toString(),
                                  time: activity['time'].toString(),
                                  color: activity['color'] as Color,
                                ),
                                if (index < liveItems.length - 1)
                                  const Divider(color: Color(0xFFE5D7C9)),
                              ],
                            );
                          }),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Logout Button
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
                  onTap: _showLogoutDialog,
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
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Logout',
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
                      ],
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

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    String? imageAsset,
    double? imageSize,
    double? imageScale,
    double? imageOffsetX,
    double? imageOffsetY,
    required Color color,
  }) {
    return Container(
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
            blurRadius: 8,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7E9DF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: AppIconOrImage(
                icon: icon,
                imageAsset: imageAsset,
                iconColor: color,
                size: imageSize ?? 20,
                scale: imageScale ?? 1.0,
                offsetX: imageOffsetX ?? 0.0,
                offsetY: imageOffsetY ?? 0.0,
              ),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B1B12),
                  ),
                ),
              ),
            ),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF7D6C62),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator({
    required Color color,
    required String label,
    required int count,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF7D6C62),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7D6C62),
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF9A8B82),
            ),
          ),
        ],
      ),
    );
  }

  // ========== CARS TAB ==========
  Widget _buildcarsTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF5A1F),
        ),
      );
    }

    return RefreshIndicator(
      key: _carsRefreshKey,
      onRefresh: () => _loadcarsFromAPI(),
      color: const Color(0xFFFF5A1F),
      child: Column(
        children: [
          // Add car Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
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
                  onTap: _navigateToAddcarScreen,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
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
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Add New Car',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
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
          ),

          // Cars List
          Expanded(
            child: _cars.isEmpty
                ? Center(
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
                    child: const Icon(
                      Icons.directions_car,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Cars Added Yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2B1B12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap "Add New Car" to get started',
                    style: TextStyle(color: Color(0xFF7D6C62)),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _cars.length,
              itemBuilder: (context, index) {
                final car = _cars[index];
                return _buildcarCard(car);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToEditcarScreen(Map<String, dynamic> car) async {
    final bool isCarRented = (car['status'] ?? '').toString().toLowerCase() == 'rented';
    if (isCarRented) {
      _showSnackBar(
        'Cannot edit vehicle while it is rented. Editing is disabled until the ride ends.',
        const Color(0xFFEF4444),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PartnerEditcar(car: car),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        final index = _cars.indexWhere((b) => b['id'] == result['id']);
        if (index != -1) {
          _cars[index] = result;
        }
        _updateStatsAfterAdd();
        _initMarkers();
      });
    }
  }

  Widget _buildcarCard(Map<String, dynamic> car) {
    final bool isCarRented = (car['status'] ?? '').toString().toLowerCase() == 'rented';
    Color statusColor;
    String statusText;
    switch (car['status']) {
      case 'available':
        statusColor = const Color(0xFF2E7D32);
        statusText = 'Available';
        break;
      case 'rented':
        statusColor = const Color(0xFFD32F2F);
        statusText = 'Rented';
        break;
      case 'maintenance':
        statusColor = const Color(0xFFFF5A1F);
        statusText = 'Maintenance';
        break;
      default:
        statusColor = const Color(0xFF7D6C62);
        statusText = 'Unknown';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFD6C6B8),
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
      padding: const EdgeInsets.only(bottom: 4.5),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                      imageUrl: (car['images'] is List && (car['images'] as List).isNotEmpty)
                          ? (car['images'] as List).first.toString()
                          : null,
                      iconColor: const Color(0xFFFF5A1F),
                      size: 32,
                      borderRadius: BorderRadius.circular(8),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        car['model'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2B1B12),
                        ),
                      ),
                      Text(
                        '${car['type']} • ${car['fuelType']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7D6C62),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 12, color: Color(0xFFFF5A1F)),
                          const SizedBox(width: 4),
                          Text(
                            car['rating'].toString(),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF2B1B12)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${car['reviewCount']} reviews)',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF7D6C62)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${car['dailyRate']}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2B1B12),
                      ),
                    ),
                    const Text(
                      '/day',
                      style: TextStyle(fontSize: 10, color: Color(0xFF7D6C62)),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 10,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 3.5),
                    decoration: BoxDecoration(
                      color: isCarRented ? const Color(0xFF8A7A70) : const Color(0xFFCC3F0C),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isCarRented
                          ? null
                          : [
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
                          if (isCarRented) {
                            _showSnackBar(
                              'Cannot edit vehicle while it is rented. Editing is disabled until ride ends.',
                              const Color(0xFFEF4444),
                            );
                            return;
                          }
                          _navigateToEditcarScreen(car);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            gradient: isCarRented
                                ? const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Color(0xFFB5A496), Color(0xFF9E8E81)],
                                  )
                                : const LinearGradient(
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isCarRented) ...[
                                const Icon(Icons.lock_outline, size: 14, color: Colors.white),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                isCarRented ? 'Edit (Rented)' : 'Edit',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withOpacity(isCarRented ? 0.85 : 1.0),
                                  fontSize: 14,
                                  shadows: isCarRented
                                      ? null
                                      : const [
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
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: isCarRented
                      ? () {
                          _showSnackBar(
                            'Cannot delete vehicle while it is rented.',
                            const Color(0xFFEF4444),
                          );
                        }
                      : () {
                          _showDeleteConfirmation(car);
                        },
                  icon: Icon(
                    Icons.delete,
                    color: isCarRented ? const Color(0xFFB5A496) : const Color(0xFF2B1B12),
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ========== EARNINGS TAB ==========
  Widget _buildEarningsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Total Earnings Card
          Container(
            padding: const EdgeInsets.only(bottom: 5.0),
            decoration: BoxDecoration(
              color: const Color(0xFFCC3F0C),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFCC3F0C).withOpacity(0.38),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
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
                  width: 1.2,
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Total Earnings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${_totalEarnings.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Color(0x66000000),
                          offset: Offset(0, 1.5),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.trending_up, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '+12% from last month',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 12,
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

          // Today's Earnings
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFD6C6B8),
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
            padding: const EdgeInsets.only(bottom: 4.5),
            child: Container(
              padding: const EdgeInsets.all(20),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Today's Earnings",
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF7D6C62),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${_todayEarnings.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2B1B12),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7E9DF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.today,
                      color: Color(0xFFFF5A1F),
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Earnings Breakdown
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFD6C6B8),
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
                  color: const Color(0xFFE2D3C4),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Earnings Breakdown',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2B1B12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildEarningItem(
                    title: 'Car Rentals',
                    amount: 10450,
                    percentage: 83,
                  ),
                  const SizedBox(height: 12),
                  _buildEarningItem(
                    title: 'Late Fees',
                    amount: 1250,
                    percentage: 10,
                  ),
                  const SizedBox(height: 12),
                  _buildEarningItem(
                    title: 'Insurance',
                    amount: 880,
                    percentage: 7,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningItem({
    required String title,
    required double amount,
    required int percentage,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF7D6C62),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Column(
            children: [
              LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: const Color(0xFFF5EFE9),
                color: const Color(0xFFFF5A1F),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 4),
              Text(
                '$percentage%',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF7D6C62),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF2B1B12),
          ),
        ),
      ],
    );
  }

  // ========== LOCATION TAB ==========
  Widget _buildLocationTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF5A1F),
        ),
      );
    }

    return Column(
      children: [
        // Map Legend
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem(
                color: const Color(0xFF2E7D32),
                label: 'Available',
                count: _availablecars,
              ),
              _buildLegendItem(
                color: const Color(0xFFD32F2F),
                label: 'Rented',
                count: _rentedcars,
              ),
              _buildLegendItem(
                color: const Color(0xFFFF5A1F),
                label: 'Maintenance',
                count: _maintenancecars,
              ),
            ],
          ),
        ),

        // Map
        Expanded(
          child: FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _initialPosition,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.carzzz.app',
                maxZoom: 19,
                minZoom: 3,
              ),
              MarkerLayer(
                markers: _flutterMarkers,
              ),
            ],
          ),
        ),

        // Bottom Info Bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Total Cars on Map',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7D6C62),
                    ),
                  ),
                  Text(
                    '${_cars.length} Cars',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2B1B12),
                    ),
                  ),
                ],
              ),
              Container(
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
                      _mapController.move(_initialPosition, 14.0);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.my_location, size: 18, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'Center Map',
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
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required int count,
  }) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ($count)',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF2B1B12),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ========== HELPER METHODS ==========
  void _showcarDetailsBottomSheet(Map<String, dynamic> car) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        Color statusColor;
        String statusText;
        switch (car['status']) {
          case 'available':
            statusColor = const Color(0xFF2E7D32);
            statusText = 'Available';
            break;
          case 'rented':
            statusColor = const Color(0xFFD32F2F);
            statusText = 'Rented';
            break;
          case 'maintenance':
            statusColor = const Color(0xFFFF5A1F);
            statusText = 'Maintenance';
            break;
          default:
            statusColor = const Color(0xFF7D6C62);
            statusText = 'Unknown';
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFFFAF7F4),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                    child: const Icon(
                      Icons.directions_car,
                      size: 28,
                      color: Color(0xFFFF5A1F),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          car['model'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2B1B12),
                          ),
                        ),
                        Text(
                          '${car['type']} • ${car['fuelType']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7D6C62),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFE5D7C9)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.star, size: 16, color: Color(0xFFFF5A1F)),
                  const SizedBox(width: 8),
                  Text(
                    '${car['rating']} (${car['reviewCount']} reviews)',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF2B1B12)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.currency_rupee, size: 16, color: Color(0xFFFF5A1F)),
                  const SizedBox(width: 8),
                  Text(
                    '₹${car['dailyRate']} per day',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFF5A1F),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Color(0xFFFF5A1F)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lat: ${car['location']['lat'].toStringAsFixed(6)}, Lng: ${car['location']['lng'].toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF7D6C62)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> car) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: const Color(0xFFFAF7F4),
        title: const Text(
          'Delete Car',
          style: TextStyle(color: Color(0xFF2B1B12), fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete ${car['model']}? This action cannot be undone.',
          style: const TextStyle(color: Color(0xFF7D6C62)),
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
              setState(() {
                _cars.remove(car);
                _updateStatsAfterAdd();
              });
              _initMarkers();
              Navigator.pop(context);
              _showSnackBar('${car['model']} deleted successfully!', const Color(0xFF2E7D32));
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
                  'Delete',
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
              await prefs.remove('partner_token');
              await prefs.remove('partner_data');
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
}