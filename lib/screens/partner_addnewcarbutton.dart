// FILE: partner_addnewcar.dart
// PURPOSE: Dedicated screen for partners to add a new car with all required details
// NEW FEATURES:
// - Complete form with all required fields: Model, Registration Number, Type, Fuel Type, Daily Rate
// - Multiple image upload (max 6 images)
// - Description field
// - Offer/Discount selection
// - Map-based location selection (tap on map to set coordinates)
// - Proper validation for all fields
// - Backend API integration with retry logic

/*

partner_addnewcarbutton.dart
 */

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class PartnerAddNewcar extends StatefulWidget {
  const PartnerAddNewcar({super.key});

  @override
  State<PartnerAddNewcar> createState() => _PartnerAddNewcarState();
}

class _PartnerAddNewcarState extends State<PartnerAddNewcar> {
  final _formKey = GlobalKey<FormState>();
  bool _isGettingCurrentLocation = false;
  final ImagePicker _imagePicker = ImagePicker();
  final MapController _mapController = MapController();

  // Form controllers
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _registrationController = TextEditingController();
  final TextEditingController _dailyRateController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Dropdown values
  String _carType = 'Car';
  String _fuelType = 'Petrol';
  String _selectedOffer = 'No Offer';

  // Image list
  final List<XFile> _carImages = [];

  // Location
  LatLng? _selectedLocation;
  static const LatLng _initialPosition = LatLng(28.6139, 77.2090);

  // UI states
  bool _isSubmitting = false;
  bool _isFormValid = false;

  // API Base URL with dynamic switching
  static const int _connectionTimeout = 30;

  // CHANGE THIS MANUALLY:
  // Set to false for emulator, true for physical device
  static const bool _usePhysicalDevice = false;

  String get _baseUrl {
    if (_usePhysicalDevice) {
      return 'http://10.0.2.2:3000';
    } else {
      return 'https://carzzz-frontend.onrender.com';
    }
  }

  // Offer options
  final List<String> _offerOptions = ['No Offer', '10% off', '20% off', '30% off', '50% off'];

  // car type options
  final List<String> _carTypes = ['Car', 'Sports Car', 'Super Car', 'Electric'];

  // Fuel type options
  final List<String> _fuelTypes = ['Petrol', 'Electric', 'CNG'];

  @override
  void dispose() {
    _modelController.dispose();
    _registrationController.dispose();
    _dailyRateController.dispose();
    _descriptionController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_carImages.length >= 6) {
      _showSnackBar('Maximum 6 images allowed', const Color(0xFFEF4444));
      return;
    }

    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _carImages.add(pickedFile);
      });
    }
  }

  Future<String?> _uploadImageToCloudinary(XFile imageFile) async {
    try {
      const String cloudName = 'cyxukrg0';
      const String uploadPreset = 'carzzz_cars';

      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 40));
      final responseData = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
        final jsonResponse = json.decode(responseData);
        final String? secureUrl = jsonResponse['secure_url'];
        print('✅ Cloudinary upload success: $secureUrl');
        return secureUrl;
      } else {
        print('❌ Cloudinary upload failed (${streamedResponse.statusCode}): $responseData');
        return null;
      }
    } catch (e) {
      print('❌ Error uploading to Cloudinary: $e');
      return null;
    }
  }

  void _removeImage(int index) {
    setState(() {
      _carImages.removeAt(index);
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingCurrentLocation = true;
    });

    try {
      PermissionStatus status = await Permission.location.request();

      if (status.isGranted) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );

        setState(() {
          _selectedLocation = LatLng(position.latitude, position.longitude);
          _mapController.move(_selectedLocation!, 15.0);
        });

        _showSnackBar(
          'Location set to your current position!',
          const Color(0xFF10B981),
        );
      } else if (status.isDenied) {
        _showSnackBar(
          'Location permission denied. Please enable location to use this feature.',
          const Color(0xFFEF4444),
        );
      } else if (status.isPermanentlyDenied) {
        _showSnackBar(
          'Location permission permanently denied. Please enable in settings.',
          const Color(0xFFEF4444),
        );
      }
    } catch (e) {
      print('Error getting current location: $e');
      _showSnackBar(
        'Failed to get current location. Please select manually on map.',
        const Color(0xFFEF4444),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGettingCurrentLocation = false;
        });
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_carImages.isEmpty) {
      _showSnackBar('Please add at least one car image', const Color(0xFFEF4444));
      return;
    }

    if (_selectedLocation == null) {
      _showSnackBar('', const Color(0xFFEF4444));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('partner_token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      // Upload images to Cloudinary
      final List<String> uploadedImageUrls = [];
      for (int i = 0; i < _carImages.length; i++) {
        final img = _carImages[i];
        if (img.path.startsWith('http://') || img.path.startsWith('https://')) {
          uploadedImageUrls.add(img.path);
        } else {
          final url = await _uploadImageToCloudinary(img);
          if (url != null) {
            uploadedImageUrls.add(url);
          } else {
            uploadedImageUrls.add(img.path);
          }
        }
      }

      // Prepare car data
      final carData = {
        'model': _modelController.text.trim(),
        'registrationNumber': _registrationController.text.trim(),
        'type': _carType,
        'fuelType': _fuelType,
        'dailyRate': int.parse(_dailyRateController.text.trim()),
        'location': {
          'lat': _selectedLocation!.latitude,
          'lng': _selectedLocation!.longitude,
        },
        'description': _descriptionController.text.trim(),
        'offer': _selectedOffer != 'No Offer'
            ? {
          'discountPercentage': int.parse(_selectedOffer.replaceAll(' off', '').replaceAll('%', '')),
          'validUntil': DateTime.now().add(const Duration(days: 30)).toIso8601String()
        }
            : null,
        'images': uploadedImageUrls,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/api/partner/cars'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(carData),
      ).timeout(const Duration(seconds: _connectionTimeout));

      final data = json.decode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        // Prepare return data
        final newcar = {
          'id': data['car']['_id'],
          'model': _modelController.text.trim(),
          'type': _carType,
          'fuelType': _fuelType,
          'dailyRate': int.parse(_dailyRateController.text.trim()),
          'status': 'available',
          'rating': 0.0,
          'reviewCount': 0,
          'location': {'lat': _selectedLocation!.latitude, 'lng': _selectedLocation!.longitude},
          'images': uploadedImageUrls,
          'description': _descriptionController.text.trim(),
          'offer': _selectedOffer != 'No Offer' ? _selectedOffer : null,
          'registrationNumber': _registrationController.text.trim(),
        };

        _showSnackBar('car added successfully!', const Color(0xFF10B981));
        Navigator.pop(context, newcar);
      } else {
        throw Exception(data['message'] ?? 'Failed to add car');
      }
    } on TimeoutException {
      _showSnackBar('Connection timeout. Please try again.', const Color(0xFFEF4444));
    } on SocketException {
      _showSnackBar('Cannot connect to server. Please check your connection.', const Color(0xFFEF4444));
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', const Color(0xFFEF4444));
      print('Error adding car: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
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

  // ========== REDESIGNED UI - LIGHT MODE ==========
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
              // ========== REDESIGNED HEADER ==========
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7F4),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6D6C8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFF2B1B12),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Add New Car',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2B1B12),
                      ),
                    ),
                    // REMOVED: const Spacer()
                    // REMOVED: Container with IconButton
                  ],
                ),
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  onChanged: () {
                    setState(() {
                      _isFormValid = _formKey.currentState?.validate() ?? false;
                    });
                  },
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ========== car MODEL ==========
                        _buildTextField(
                          controller: _modelController,
                          label: 'Car Model *',
                          hint: 'e.g., Suziki Dzire',
                          icon: Icons.directions_car,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // ========== REGISTRATION NUMBER ==========
                        _buildTextField(
                          controller: _registrationController,
                          label: 'Registration Number *',
                          hint: 'e.g., KA-01-AB-1234',
                          icon: Icons.confirmation_number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // ========== car TYPE ==========
                        _buildDropdownField(
                          label: 'Car Type *',
                          icon: Icons.category,
                          value: _carType,
                          items: _carTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _carType = value!;
                            });
                          },
                          validator: (value) => value == null ? '' : null,
                        ),
                        const SizedBox(height: 16),

                        // ========== FUEL TYPE ==========
                        _buildDropdownField(
                          label: 'Fuel Type *',
                          icon: Icons.local_gas_station,
                          value: _fuelType,
                          items: _fuelTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _fuelType = value!;
                            });
                          },
                          validator: (value) => value == null ? '' : null,
                        ),
                        const SizedBox(height: 16),

                        // ========== DAILY RATE ==========
                        _buildTextField(
                          controller: _dailyRateController,
                          label: 'Daily Rate (₹) *',
                          hint: 'e.g., 199',
                          icon: Icons.currency_rupee,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '';
                            }
                            final rate = int.tryParse(value);
                            if (rate == null || rate <= 0) {
                              return 'Please enter a valid positive number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // ========== car IMAGES ==========
                        const Text(
                          'Car Images (Max 6) *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2B1B12),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _carImages.length + 1,
                            itemBuilder: (context, index) {
                              if (index == _carImages.length) {
                                return GestureDetector(
                                  onTap: _pickImage,
                                  child: Container(
                                    width: 100,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAF7F4),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE5D7C9)),
                                    ),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate, size: 40, color: Color(0xFFFF5A1F)),
                                        SizedBox(height: 4),
                                        Text('Add Image', style: TextStyle(fontSize: 12, color: Color(0xFF7D6C62))),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              return Stack(
                                children: [
                                  Container(
                                    width: 100,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      image: DecorationImage(
                                        image: _carImages[index].path.startsWith('http')
                                            ? NetworkImage(_carImages[index].path) as ImageProvider
                                            : FileImage(File(_carImages[index].path)),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => _removeImage(index),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        if (_carImages.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Please add at least one image',
                              style: TextStyle(fontSize: 12, color: Colors.red[400]),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // ========== DESCRIPTION ==========
                        _buildTextField(
                          controller: _descriptionController,
                          label: 'Description *',
                          hint: 'Describe your car...',
                          icon: Icons.description,
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // ========== OFFER ==========
                        const Text(
                          'Offer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2B1B12),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7F4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE5D7C9),
                              width: 1,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedOffer,
                              isExpanded: true,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              dropdownColor: const Color(0xFFFAF7F4),
                              style: const TextStyle(color: Color(0xFF2B1B12)),
                              items: _offerOptions.map((offer) {
                                return DropdownMenuItem(
                                  value: offer,
                                  child: Text(offer),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedOffer = value!;
                                });
                              },
                              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF7D6C62)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ========== LOCATION ==========
                        const Text(
                          'Car Location *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2B1B12),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Current Location Button
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5A1F),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF5A1F).withOpacity(0.3),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _isGettingCurrentLocation ? null : _getCurrentLocation,
                            icon: _isGettingCurrentLocation
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                                : const Icon(Icons.my_location, color: Colors.white),
                            label: Text(
                              _isGettingCurrentLocation ? 'Getting location...' : 'Use My Current Location',
                              style: const TextStyle(color: Colors.white),
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
                        const SizedBox(height: 12),

                        // Or tap on map text
                        const Center(
                          child: Text(
                            'OR',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF7D6C62),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Map Container
                        Container(
                          height: 250,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE5D7C9),
                              width: 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: _initialPosition,
                                initialZoom: 14.0,
                                onTap: (tapPosition, point) {
                                  setState(() {
                                    _selectedLocation = point;
                                  });
                                  _showSnackBar(
                                    'Location set: ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
                                    const Color(0xFF10B981),
                                  );
                                },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.carzzz.app',
                                ),
                                if (_selectedLocation != null)
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: _selectedLocation!,
                                        width: 40,
                                        height: 40,
                                        child: const Icon(
                                          Icons.location_on,
                                          color: Colors.red,
                                          size: 40,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedLocation != null
                              ? 'Selected: ${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}'
                              : 'Tap on the map to set car location',
                          style: TextStyle(
                            fontSize: 12,
                            color: _selectedLocation != null ? const Color(0xFFFF5A1F) : const Color(0xFF7D6C62),
                          ),
                        ),
                        if (_selectedLocation == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Please select car location',
                              style: TextStyle(fontSize: 12, color: Colors.red[400]),
                            ),
                          ),
                        const SizedBox(height: 32),

                        // ========== SUBMIT BUTTON ==========
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5A1F),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF5A1F).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: (_isFormValid && _carImages.isNotEmpty && _selectedLocation != null && !_isSubmitting)
                                ? _submitForm
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              shadowColor: Colors.transparent,
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                                : const Text(
                              'Add Car',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
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

// ========== CUSTOM WIDGETS - DARK MODE ==========
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2B1B12),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE5D7C9),
              width: 1,
            ),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: const TextStyle(color: Color(0xFF2B1B12)),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF9A8B82)),
              prefixIcon: Icon(icon, color: const Color(0xFFFF5A1F), size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2B1B12),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE5D7C9),
              width: 1,
            ),
          ),
          child: DropdownButtonFormField<String>(
            value: value.isNotEmpty ? value : null,
            dropdownColor: const Color(0xFFFAF7F4),
            style: const TextStyle(color: Color(0xFF2B1B12)),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: const Color(0xFFFF5A1F), size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            items: items,
            onChanged: onChanged,
            validator: validator,
            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF7D6C62)),
          ),
        ),
      ],
    );
  }
  }

