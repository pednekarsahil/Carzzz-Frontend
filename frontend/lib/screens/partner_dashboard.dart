
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

  // API Base URL
  static const int _connectionTimeout = 30;
  static const int _autoRefreshInterval = 30;
  static const bool _usePhysicalDevice = true;

  String get _baseUrl {
    if (_usePhysicalDevice) {
      return 'http://10.0.2.2:3000';
    } else {
      return 'https://bikerzzz-backend.onrender.com';
    }
  }

  // Stats
  int _totalcars = 0;
  int _availablecars = 0;
  int _rentedcars = 0;
  int _maintenancecars = 0;
  final double _totalEarnings = 12580.0;
  final double _todayEarnings = 1250.0;
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
    _checkTokenAndLoadData();
    _loadTransactions();
    _startActiveViewsSimulation();
    _startAutoRefresh();
  }

  // Check token and load data
  Future<void> _checkTokenAndLoadData() async {
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
        if (mounted && _selectedIndex == 0) {
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
        'transports': ['websocket'],
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
        'reconnectionAttempts': 10,
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
        _showSnackBar('Your Car "${data['carModel']}" has been rented!', const Color(0xFF10B981));
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
          if (mounted) {
            setState(() {
              _totalcars = stats['totalcars'] ?? _totalcars;
              _availablecars = stats['availablecars'] ?? _availablecars;
              _rentedcars = stats['rentedcars'] ?? _rentedcars;
              _maintenancecars = stats['maintenancecars'] ?? _maintenancecars;
            });
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
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Session Expired',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Your session has expired. Please login again to continue.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Pop all the way back to login
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Login Again'),
          ),
        ],
      ),
    );
  }

  // ========== UI BUILD ==========
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.95),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.business_center,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.partnerData['businessName'] ?? 'My Business',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            widget.partnerData['email'] ?? 'partner@example.com',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        onPressed: _showLogoutDialog,
                        icon: const Icon(
                          Icons.logout,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

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
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.95),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: BottomNavigationBar(
                  currentIndex: _selectedIndex,
                  onTap: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: const Color(0xFF3B82F6),
                  unselectedItemColor: Colors.grey[500],
                  backgroundColor: Colors.transparent,
                  selectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 12,
                  ),
                  elevation: 0,
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.dashboard_outlined),
                      activeIcon: Icon(Icons.dashboard),
                      label: 'Dashboard',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.directions_car_outlined),
                      activeIcon: Icon(Icons.directions_car),
                      label: 'My Cars',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.monetization_on_outlined),
                      activeIcon: Icon(Icons.monetization_on),
                      label: 'Earnings',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.location_on_outlined),
                      activeIcon: Icon(Icons.location_on),
                      label: 'Locations',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== DASHBOARD TAB ==========
  Widget _buildDashboardTab() {
    return RefreshIndicator(
      key: _dashboardRefreshKey,
      onRefresh: _manualRefresh,
      color: const Color(0xFF3B82F6),
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
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                  title: 'Total Earnings',
                  value: '₹${_totalEarnings.toStringAsFixed(0)}',
                  icon: Icons.wallet,
                  color: const Color(0xFF3B82F6),
                ),
                _buildStatCard(
                  title: "Today's Earnings",
                  value: '₹${_todayEarnings.toStringAsFixed(0)}',
                  icon: Icons.today,
                  color: const Color(0xFF10B981),
                ),
                _buildStatCard(
                  title: 'Total Car',
                  value: '$_totalcars',
                  icon: Icons.directions_car,
                  color: const Color(0xFF8B5CF6),
                ),
                _buildStatCard(
                  title: 'Active Views',
                  value: '$_activeViews',
                  icon: Icons.visibility,
                  color: const Color(0xFFF59E0B),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Car Status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1E293B),
                    Color(0xFF0F172A),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey[700]!,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Car Status',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildStatusIndicator(
                        color: const Color(0xFF10B981),
                        label: 'Available',
                        count: _availablecars,
                      ),
                      _buildStatusIndicator(
                        color: const Color(0xFFEF4444),
                        label: 'Rented',
                        count: _rentedcars,
                      ),
                      _buildStatusIndicator(
                        color: const Color(0xFFF59E0B),
                        label: 'Maintenance',
                        count: _maintenancecars,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Recent Activity
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1E293B),
                    Color(0xFF0F172A),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey[700]!,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_recentActivities.isEmpty)
                    _buildActivityItem(
                      icon: Icons.payments,
                      title: 'Payment Received',
                      subtitle: '₹199 from Rajesh Kumar',
                      time: '5 hours ago',
                      color: const Color(0xFF3B82F6),
                    )
                  else
                    ..._recentActivities.map((activity) => Column(
                      children: [
                        _buildActivityItem(
                          icon: activity['icon'],
                          title: activity['title'],
                          subtitle: activity['subtitle'],
                          time: activity['time'],
                          color: activity['color'],
                        ),
                        const Divider(color: Colors.grey),
                      ],
                    )),
                  const Divider(color: Colors.grey),
                  _buildActivityItem(
                    icon: Icons.build,
                    title: 'Car in Maintenance',
                    subtitle: 'Royal Enfield Classic 350',
                    time: 'Yesterday',
                    color: const Color(0xFFF59E0B),
                  ),
                ],
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
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[700]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.5)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[400],
            ),
          ),
        ],
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
              color: color.withOpacity(0.2),
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
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
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
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.5)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
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
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
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
          color: Color(0xFF3B82F6),
        ),
      );
    }

    return RefreshIndicator(
      key: _carsRefreshKey,
      onRefresh: () => _loadcarsFromAPI(),
      color: const Color(0xFF3B82F6),
      child: Column(
        children: [
          // Add car Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _navigateToAddcarScreen,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Add New Car',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  shadowColor: Colors.transparent,
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
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 10,
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
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap "Add New Car" to get started',
                    style: TextStyle(color: Colors.grey[400]),
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
    Color statusColor;
    String statusText;
    switch (car['status']) {
      case 'available':
        statusColor = const Color(0xFF10B981);
        statusText = 'Available';
        break;
      case 'rented':
        statusColor = const Color(0xFFEF4444);
        statusText = 'Rented';
        break;
      case 'maintenance':
        statusColor = const Color(0xFFF59E0B);
        statusText = 'Maintenance';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Unknown';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[700]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.directions_car,
                  size: 32,
                  color: Colors.white,
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
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${car['type']} • ${car['fuelType']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 12, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 4),
                        Text(
                          car['rating'].toString(),
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${car['reviewCount']} reviews)',
                          style: TextStyle(fontSize: 11, color: Colors.grey[400]),
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
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                  const Text(
                    '/day',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 10,
                        color: statusColor,
                        fontWeight: FontWeight.w500,
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
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      _navigateToEditcarScreen(car);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      shadowColor: Colors.transparent,
                    ),
                    child: const Text('Edit'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: () {
                    _showDeleteConfirmation(car);
                  },
                  icon: const Icon(Icons.delete, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(0.3),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'Total Earnings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${_totalEarnings.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
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
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Today's Earnings
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E293B),
                  Color(0xFF0F172A),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey[700]!,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                ),
              ],
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
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${_todayEarnings.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.today,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Earnings Breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E293B),
                  Color(0xFF0F172A),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey[700]!,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Earnings Breakdown',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Column(
            children: [
              LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: Colors.grey[800],
                color: const Color(0xFF3B82F6),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 4),
              Text(
                '$percentage%',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
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
            color: Colors.white,
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
          color: Color(0xFF3B82F6),
        ),
      );
    }

    return Column(
      children: [
        // Map Legend
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem(
                color: Colors.green,
                label: 'Available',
                count: _availablecars,
              ),
              _buildLegendItem(
                color: Colors.red,
                label: 'Rented',
                count: _rentedcars,
              ),
              _buildLegendItem(
                color: Colors.orange,
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
                userAgentPackageName: 'com.example.carrzz',
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
            color: const Color(0xFF1E293B),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 5,
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
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    '${_cars.length} Cars',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    _mapController.move(_initialPosition, 14.0);
                  },
                  icon: const Icon(Icons.my_location, size: 18, color: Colors.white),
                  label: const Text(
                    'Center Map',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    shadowColor: Colors.transparent,
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
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[300],
            fontWeight: FontWeight.w500,
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
            statusColor = const Color(0xFF10B981);
            statusText = 'Available';
            break;
          case 'rented':
            statusColor = const Color(0xFFEF4444);
            statusText = 'Rented';
            break;
          case 'maintenance':
            statusColor = const Color(0xFFF59E0B);
            statusText = 'Maintenance';
            break;
          default:
            statusColor = Colors.grey;
            statusText = 'Unknown';
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E293B),
                Color(0xFF0F172A),
              ],
            ),
            borderRadius: const BorderRadius.vertical(
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
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      size: 28,
                      color: Colors.white,
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
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${car['type']} • ${car['fuelType']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
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
              const Divider(color: Colors.grey),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.star, size: 16, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  Text(
                    '${car['rating']} (${car['reviewCount']} reviews)',
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.currency_rupee, size: 16, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  Text(
                    '₹${car['dailyRate']} per day',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lat: ${car['location']['lat'].toStringAsFixed(6)}, Lng: ${car['location']['lng'].toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Delete Car',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete ${car['model']}? This action cannot be undone.',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
              ).createShader(bounds),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
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
              _showSnackBar('${car['model']} deleted successfully!', const Color(0xFF10B981));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
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
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Logout',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
              ).createShader(bounds),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}