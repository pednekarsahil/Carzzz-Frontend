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
                      'Edit car',
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
                                'car Status',
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
                          label: 'car Model *',
                          hint: 'e.g., Honda Activa 125',
                          icon: Icons.directions_car,
                          initialValue: _carModel,
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
                          label: 'car Type *',
                          icon: Icons.category,
                          value: _carType,
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
                          hint: 'e.g., 199',
                          icon: Icons.currency_rupee,
                          initialValue: _dailyRate,
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

                        // car Images
                        const Text(
                          'car Images (Max 6) *',
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
                                      onTap: () {
                                        setState(() {
                                          _carImages.removeAt(index);
                                        });
                                      },
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

                        // Location
                        const Text(
                          'car Location *',
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
                                onTap: (tapPosition, point) {
                                  setState(() {
                                    _carLocation = point;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Location updated: ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
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
                        const Text(
                          'Tap on the map to update car location',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7D6C62),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // ========== SAVE BUTTON - GRADIENT ==========
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
                            onPressed: _saveChanges,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              shadowColor: Colors.transparent,
                            ),
                            child: const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
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
            initialValue: initialValue,
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
    if (_carImages.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 6 images allowed'),
          backgroundColor: Colors.red,
        ),
      );
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
      final responseData = await streamedResponse.bytesToString();

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

    // Return updated car to previous screen
    Navigator.pop(context, updatedcar);
  }
}