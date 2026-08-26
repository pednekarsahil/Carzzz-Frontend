import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:8000/api';

  // Check server health
  static Future<bool> checkServerHealth() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/test'),
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      print('Server health check failed: $e');
      return false;
    }
  }

  // User signup
  static Future<Map<String, dynamic>> signupUser({
    required String fullname,
    required String email,
    required int age,
    required DateTime dob,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'fullname': fullname,
          'email': email,
          'age': age,
          'dob': dob.toIso8601String(),
          'password': password,
        }),
      );

      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // User login
  static Future<Map<String, dynamic>> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Business signup
  static Future<Map<String, dynamic>> signupBusiness({
    required String fullname,
    required String email,
    required String password,
    required String businessName,
    required String businessType,
    required String phone,
    required String address,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/business/signup'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'fullname': fullname,
          'email': email,
          'password': password,
          'businessName': businessName,
          'businessType': businessType,
          'phone': phone,
          'address': address,
        }),
      );

      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Business login
  static Future<Map<String, dynamic>> loginBusiness({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/business/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Send verification link
  static Future<Map<String, dynamic>> sendVerificationLink(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/send-verification-link'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Send business verification link
  static Future<Map<String, dynamic>> sendBusinessVerificationLink(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/business/send-verification-link'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}