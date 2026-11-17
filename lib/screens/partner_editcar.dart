// FILE: partner_editcar.dart
// PURPOSE: Dedicated screen for partners to edit car details with maintenance/availability controls

/*

file name partner_editcar.dart

*/
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PartnerEditcar extends StatefulWidget {
  final Map<String, dynamic> car;

  const PartnerEditcar({super.key, required this.car});

  @override
  State<PartnerEditcar> createState() => _PartnerEditcarState();
}

class _PartnerEditcarState extends State<PartnerEditcar> {
  late Map<String, dynamic> _car;
  final _formKey = GlobalKey<FormState>();

  // Form fields
  late String _carModel;
  late String _carType;
  late String _fuelType;
  late String _dailyRate;
  late List<XFile> _carImages;
  late String _description;
  late String _selectedOffer;
  late LatLng _carLocation;

  // Offer options
  final List<String> _offerOptions = ['No Offer', '10% off', '20% off', '50% off'];

  // Map controller for location selection
  final MapController _mapController = MapController();
  static const LatLng _initialPosition = LatLng(28.6139, 77.2090);
  final ImagePicker _imagePicker = ImagePicker();

  // Track original image paths to detect changes
  List<String> _originalImagePaths = [];
  bool _isSaving = false;

  static const bool _usePhysicalDevice = false;
  String get _baseUrl {
    if (_usePhysicalDevice) {
      return 'http://10.0.2.2:3000';
    } else {
      return 'https://carzzz-frontend.onrender.com';
    }
  }

  @override
  void initState() {
    super.initState();
    _car = Map.from(widget.car);

    // FIX: Safely extract all values with proper type checking
    _carModel = _car['model']?.toString() ?? '';
    final String rawType = _car['type']?.toString() ?? '';
    const Map<String, String> legacyTypeMap = {
      'Scooter': 'Car',
      'Motorcycle': 'Sports Car',
      'Sports car': 'Super Car',
    };
    final String mappedType = legacyTypeMap[rawType] ?? rawType;
    const List<String> validCarTypes = ['Car', 'Sports Car', 'Super Car', 'Electric'];
    _carType = validCarTypes.contains(mappedType) ? mappedType : 'Car';

    final String rawFuel = _car['fuelType']?.toString() ?? '';
    const List<String> validFuelTypes = ['Petrol', 'Electric', 'CNG'];
    _fuelType = validFuelTypes.contains(rawFuel) ? rawFuel : 'Petrol';
    _dailyRate = _car['dailyRate']?.toString() ?? '0';
    _description = _car['description']?.toString() ?? '';

    // FIX: Safely handle the offer field - it could be String, Map, or null
    final offerValue = _car['offer'];
    if (offerValue == null || offerValue == 'No Offer' || offerValue.toString() == 'null') {
      _selectedOffer = 'No Offer';
    } else if (offerValue is String) {
      _selectedOffer = offerValue;
    } else if (offerValue is Map) {
      // If offer is a Map, try to extract discount percentage
      final discount = offerValue['discountPercentage'];
      if (discount != null) {
        _selectedOffer = '$discount% off';
      } else if (offerValue['offerText'] != null) {
        _selectedOffer = offerValue['offerText'].toString();
      } else {
        _selectedOffer = 'No Offer';
      }
    } else {
      _selectedOffer = offerValue.toString();
    }

    // Ensure the selected offer is in the options list, otherwise default to 'No Offer'
    if (!_offerOptions.contains(_selectedOffer)) {
      _selectedOffer = 'No Offer';
    }

    // FIX: Safely handle location
    final location = _car['location'];
    if (location != null && location is Map) {
      final lat = location['lat'];
      final lng = location['lng'];
      _carLocation = LatLng(
        lat != null ? (lat is int ? lat.toDouble() : (lat as num).toDouble()) : 28.6139,
        lng != null ? (lng is int ? lng.toDouble() : (lng as num).toDouble()) : 77.2090,
      );
    } else {
      _carLocation = _initialPosition;
    }

    // Convert image paths to XFile list
    _carImages = [];
    _originalImagePaths = [];
    final images = _car['images'];
    if (images != null && images is List) {
      for (var path in images) {
        if (path is String && path.isNotEmpty) {
          _carImages.add(XFile(path));
          _originalImagePaths.add(path);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isRented = _car['status'] == 'rented';

    return Scaffold(
      backgroundColor: const Color(0xFFEDE1D5),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFEDE1D5),
        child: SafeArea(
          child: Column(
            children: [
              // ========== REDESIGNED HEADER - LIGHT MODE ==========
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
                      'Edit Car',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2B1B12),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5A1F),
                        borderRadius: BorderRadius.circular(10),
                      ),

                    ),
                  ],
                ),
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isRented)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.lock, color: Color(0xFFDC2626), size: 24),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Vehicle Currently Rented',
                                        style: TextStyle(
                                          color: Color(0xFF991B1B),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Adding or removing photos and editing details are disabled while the vehicle is rented.',
                                        style: TextStyle(
                                          color: Color(0xFFB91C1C),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // ========== STATUS MANAGEMENT SECTION - LIGHT MODE ==========
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7F4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE5D7C9),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
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
                                  color: Color(0xFF2B1B12),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatusButton(
                                      label: 'Available',
                                      icon: Icons.check_circle,
                                      color: const Color(0xFF10B981),
                                      isSelected: _car['status'] == 'available',
                                      onTap: () {
                                        if (!isRented) {
                                          setState(() {
                                            _car['status'] = 'available';
                                          });
                                        }
                                      },
                                      isDisabled: isRented,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildStatusButton(
                                      label: 'Maintenance',
                                      icon: Icons.build,
                                      color: const Color(0xFFF59E0B),
                                      isSelected: _car['status'] == 'maintenance',
                                      onTap: () {
                                        if (!isRented) {
                                          setState(() {
                                            _car['status'] = 'maintenance';
                                          });
                                        }
                                      },
                                      isDisabled: isRented,
                                    ),
                                  ),
                                ],
                              ),
                              if (isRented)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.red.withOpacity(0.3),
                                      ),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.info_outline, color: Color(0xFFEF4444), size: 16),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'car is currently rented. Status cannot be changed until the rental period ends.',
                                            style: TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ========== FORM FIELDS - DARK MODE ==========
                        _buildTextField(
                          label: 'Car Model *',
                          hint: 'e.g., Honda City',
                          icon: Icons.directions_car,
                          initialValue: _carModel,
                          enabled: !isRented,
                          onSaved: (value) => _carModel = value?.trim() ?? '',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter car model';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        _buildDropdownField(
                          label: 'Car Type *',
                          icon: Icons.category,
                          value: _carType,
                          enabled: !isRented,
                          items: const [
                            DropdownMenuItem(value: 'Car', child: Text('Car')),
                            DropdownMenuItem(value: 'Sports Car', child: Text('Sports Car')),
                            DropdownMenuItem(value: 'Super Car', child: Text('Super Car')),
                            DropdownMenuItem(value: 'Electric', child: Text('Electric')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _carType = value!;
                            });
                          },
                          validator: (value) => value == null ? 'Please select car type' : null,
                        ),
                        const SizedBox(height: 16),

                        _buildDropdownField(
                          label: 'Fuel Type *',
                          icon: Icons.local_gas_station,
                          value: _fuelType,
                          enabled: !isRented,
                          items: const [
                            DropdownMenuItem(value: 'Petrol', child: Text('Petrol')),
                            DropdownMenuItem(value: 'Electric', child: Text('Electric')),
                            DropdownMenuItem(value: 'CNG', child: Text('CNG')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _fuelType = value!;
                            });
                          },
                          validator: (value) => value == null ? 'Please select fuel type' : null,
                        ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          label: 'Daily Rate (₹) *',
                          hint: 'e.g., 1499',
                          icon: Icons.currency_rupee,
                          initialValue: _dailyRate,
                          enabled: !isRented,
                          keyboardType: TextInputType.number,
                          onSaved: (value) => _dailyRate = value?.trim() ?? '',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter daily rate';
                            }
                            if (int.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Car Images
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Car Images (Max 6) *',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2B1B12),
                              ),
                            ),
                            if (!isRented)
                              Text(
                                '/6 photos',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF7D6C62),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: isRented ? _carImages.length : _carImages.length + 1,
                            itemBuilder: (context, index) {
                              if (index == _carImages.length) {
                                if (isRented) return const SizedBox.shrink();
                                return GestureDetector(
                                  onTap: _addImage,
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
                                        Icon(Icons.add_photo_alternate, size: 36, color: Color(0xFFFF5A1F)),
                                        SizedBox(height: 4),
                                        Text('Add Photo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF7D6C62))),
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
                                      border: Border.all(color: const Color(0xFFE5D7C9)),
                                      image: DecorationImage(
                                        image: _carImages[index].path.startsWith('http')
                                            ? NetworkImage(_carImages[index].path) as ImageProvider
                                            : FileImage(File(_carImages[index].path)),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  if (!isRented)
                                    Positioned(
                                      top: 4,
                                      right: 12,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _carImages.removeAt(index);
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFEF4444),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                        if (_carImages.isEmpty && !isRented)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Please add at least one image (max 6)',
                              style: TextStyle(fontSize: 12, color: Colors.red[400]),
                            ),
                          ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          label: 'Description *',
                          hint: 'Describe your car...',
                          icon: Icons.description,
                          initialValue: _description,
                          enabled: !isRented,
                          maxLines: 3,
                          onSaved: (value) => _description = value?.trim() ?? '',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter car description';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Offer Dropdown
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
                            color: !isRented ? const Color(0xFFFAF7F4) : const Color(0xFFEBE3DB),
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
                              style: TextStyle(color: !isRented ? const Color(0xFF2B1B12) : const Color(0xFF7D6C62)),
                              items: _offerOptions.map((offer) {
                                return DropdownMenuItem(
                                  value: offer,
                                  child: Text(offer),
                                );
                              }).toList(),
                              onChanged: isRented
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _selectedOffer = value!;
                                      });
                                    },
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: !isRented ? const Color(0xFF7D6C62) : const Color(0xFF9E8E81),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Location
                        const Text(
                          'Car Location *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2B1B12),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 250,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE5D7C9),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: _carLocation,
                                initialZoom: 14.0,
                                onTap: isRented
                                    ? null
                                    : (tapPosition, point) {
                                        setState(() {
                                          _carLocation = point;
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Location updated: , ',
                                            ),
                                            duration: const Duration(seconds: 1),
                                          ),
                                        );
                                      },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.carzzz.app',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: _carLocation,
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
                          isRented
                              ? 'Location updates are disabled while the vehicle is rented'
                              : 'Tap on the map to update car location',
                          style: TextStyle(
                            fontSize: 12,
                            color: isRented ? const Color(0xFFEF4444) : const Color(0xFF7D6C62),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // ========== SAVE BUTTON - GRADIENT ==========
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isRented ? const Color(0xFFB5A496) : const Color(0xFFFF5A1F),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isRented
                                ? null
                                : [
                                    BoxShadow(
                                      color: const Color(0xFFFF5A1F).withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: ElevatedButton(
                            onPressed: (isRented || _isSaving) ? null : _saveChanges,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.white.withOpacity(0.7),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              shadowColor: Colors.transparent,
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (isRented) ...[
                                        const Icon(Icons.lock, size: 18, color: Colors.white),
                                        const SizedBox(width: 8),
                                      ],
                                      Text(
                                        isRented ? 'Cannot Edit (Vehicle Rented)' : 'Save Changes',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
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
    required String label,
    required String hint,
    required IconData icon,
    required String initialValue,
    required Function(String?) onSaved,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool enabled = true,
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
            color: enabled ? const Color(0xFFFAF7F4) : const Color(0xFFEBE3DB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE5D7C9),
              width: 1,
            ),
          ),
          child: TextFormField(
            initialValue: initialValue,
            enabled: enabled,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: TextStyle(
              color: enabled ? const Color(0xFF2B1B12) : const Color(0xFF7D6C62),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF9A8B82)),
              prefixIcon: Icon(
                icon,
                color: enabled ? const Color(0xFFFF5A1F) : const Color(0xFF9E8E81),
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: validator,
            onSaved: onSaved,
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
    bool enabled = true,
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
            color: enabled ? const Color(0xFFFAF7F4) : const Color(0xFFEBE3DB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE5D7C9),
              width: 1,
            ),
          ),
          child: DropdownButtonFormField<String>(
            value: value.isNotEmpty ? value : null,
            dropdownColor: const Color(0xFFFAF7F4),
            style: TextStyle(
              color: enabled ? const Color(0xFF2B1B12) : const Color(0xFF7D6C62),
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: enabled ? const Color(0xFFFF5A1F) : const Color(0xFF9E8E81),
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            items: items,
            onChanged: enabled ? onChanged : null,
            validator: validator,
            icon: Icon(
              Icons.arrow_drop_down,
              color: enabled ? const Color(0xFF7D6C62) : const Color(0xFF9E8E81),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDisabled,
  }) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : const Color(0xFFF5EFE9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE5D7C9),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isDisabled ? Colors.grey[400] : (isSelected ? color : const Color(0xFF7D6C62)),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isDisabled ? Colors.grey[400] : (isSelected ? color : const Color(0xFF7D6C62)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addImage() async {
    final bool isRented = _car['status'] == 'rented';
    if (isRented) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot add photos while vehicle is rented'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_carImages.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 6 images allowed'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFAF7F4),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD6C7B8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add Car Photo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B1B12),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5A1F).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt, color: Color(0xFFFF5A1F)),
              ),
              title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(sheetContext);
                final picked = await _imagePicker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 1200,
                  maxHeight: 1200,
                  imageQuality: 80,
                );
                if (picked != null) {
                  setState(() {
                    _carImages.add(picked);
                  });
                }
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5A1F).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_library, color: Color(0xFFFF5A1F)),
              ),
              title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(sheetContext);
                final picked = await _imagePicker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1200,
                  maxHeight: 1200,
                  imageQuality: 80,
                );
                if (picked != null) {
                  setState(() {
                    _carImages.add(picked);
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
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

  Future<void> _saveChanges() async {
    final bool isRented = _car['status'] == 'rented';
    if (isRented) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot edit vehicle while it is rented.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (_carImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one car image'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    _formKey.currentState!.save();

    setState(() {
      _isSaving = true;
    });

    try {
      // Upload any newly picked images to Cloudinary
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

      // Create updated car data map
      final updatedcar = {
        'id': _car['id'],
        'model': _carModel,
        'type': _carType,
        'fuelType': _fuelType,
        'dailyRate': int.parse(_dailyRate),
        'status': _car['status'],
        'rating': _car['rating'],
        'reviewCount': _car['reviewCount'],
        'location': {
          'lat': _carLocation.latitude,
          'lng': _carLocation.longitude,
        },
        'images': uploadedImageUrls,
        'description': _description,
        'offer': _selectedOffer != 'No Offer' ? _selectedOffer : null,
      };

      // Persist updates to backend API
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('partner_token');
        if (token != null) {
          final carId = _car['id'] ?? _car['_id'];
          final response = await http.put(
            Uri.parse('$_baseUrl/api/partner/cars/$carId'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode(updatedcar),
          ).timeout(const Duration(seconds: 30));

          if (response.statusCode != 200) {
            print('⚠️ Backend update responded with ${response.statusCode}: ${response.body}');
          } else {
            print('✅ Backend car updated successfully');
          }
        }
      } catch (e) {
        print('⚠️ Error syncing edit to backend: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Car updated successfully!'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        Navigator.pop(context, updatedcar);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving changes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
