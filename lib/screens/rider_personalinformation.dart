// File: rider_personalinformation.dart
// Description: Personal information page for riders to upload PAN card and driving licence images

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/app_icon_or_image.dart';

class RiderPersonalInformation extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool isDarkMode;

  const RiderPersonalInformation({
    super.key,
    required this.userData,
    required this.isDarkMode,
  });

  @override
  State<RiderPersonalInformation> createState() => _RiderPersonalInformationState();
}

class _RiderPersonalInformationState extends State<RiderPersonalInformation> {
  final _formKey = GlobalKey<FormState>();

  // Text editing controllers for personal information
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // Image files
  File? _panCardImage;
  File? _drivingLicenceImage;

  // Image picker instance
  final ImagePicker _picker = ImagePicker();

  // Loading states
  bool _isUploadingPan = false;
  bool _isUploadingDriving = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing data if available
    _fullNameController.text = widget.userData['fullname'] ?? '';
    _emailController.text = widget.userData['email'] ?? '';
    _phoneController.text = widget.userData['phone'] ?? '';
    _addressController.text = widget.userData['address'] ?? '';
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String type) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          if (type == 'pan') {
            _panCardImage = File(pickedFile.path);
          } else {
            _drivingLicenceImage = File(pickedFile.path);
          }
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${type == 'pan' ? 'PAN Card' : 'Driving Licence'} image selected'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadImage(String type) async {
    setState(() {
      if (type == 'pan') {
        _isUploadingPan = true;
      } else {
        _isUploadingDriving = true;
      }
    });

    // Simulate upload delay (replace with actual upload logic)
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      if (type == 'pan') {
        _isUploadingPan = false;
      } else {
        _isUploadingDriving = false;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${type == 'pan' ? 'PAN Card' : 'Driving Licence'} uploaded successfully!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _savePersonalInformation() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      // Simulate save delay (replace with actual API call)
      await Future.delayed(const Duration(seconds: 1));

      // Here you would typically send the data to your backend
      // For now, just show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Personal information saved successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      setState(() {
        _isSaving = false;
      });

      // Navigate back after save
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bool isDark = false;

    return Scaffold(
      backgroundColor: const Color(0xFFEDE1D5),
      appBar: AppBar(
        title: const Text('Personal Information', style: TextStyle(color: Color(0xFF2B1B12), fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFAF7F4),
        foregroundColor: const Color(0xFF2B1B12),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFEDE1D5),
        child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Personal Details Section
              Container(
                padding: const EdgeInsets.all(16),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Personal Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2B1B12),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Full Name
                    TextFormField(
                      controller: _fullNameController,
                      style: const TextStyle(color: Color(0xFF2B1B12)),
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        labelStyle: const TextStyle(color: Color(0xFF7D6C62)),
                        prefixIcon: const Icon(Icons.person_outline, color: Color(0xFFFF5A1F)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5D7C9)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5D7C9)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFFF5A1F), width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your full name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Email
                    TextFormField(
                      controller: _emailController,
                      style: const TextStyle(color: Color(0xFF2B1B12)),
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        labelStyle: const TextStyle(color: Color(0xFF7D6C62)),
                        prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFFF5A1F)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5D7C9)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5D7C9)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFFF5A1F), width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Phone Number
                    TextFormField(
                      controller: _phoneController,
                      style: const TextStyle(color: Color(0xFF2B1B12)),
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        labelStyle: const TextStyle(color: Color(0xFF7D6C62)),
                        prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFFFF5A1F)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5D7C9)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5D7C9)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFFF5A1F), width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your phone number';
                        }
                        if (value.length < 10) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Address
                    TextFormField(
                      controller: _addressController,
                      style: const TextStyle(color: Color(0xFF2B1B12)),
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Address',
                        labelStyle: const TextStyle(color: Color(0xFF7D6C62)),
                        prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFFFF5A1F)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5D7C9)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5D7C9)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFFF5A1F), width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your address';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Document Upload Section
              Container(
                padding: const EdgeInsets.all(16),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Document Upload',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2B1B12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please upload clear images of your PAN card and Driving Licence for verification',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7D6C62),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // PAN Card Section
                    _buildDocumentUploadCard(
                      isDark: isDark,
                      title: 'PAN Card',
                      icon: Icons.credit_card,
                      iconAsset: null, // Option to pass a PNG image asset
                      imageFile: _panCardImage,
                      isLoading: _isUploadingPan,
                      onPickImage: () => _pickImage('pan'),
                      onUpload: _panCardImage != null ? () => _uploadImage('pan') : null,
                    ),

                    const SizedBox(height: 20),

                    // Driving Licence Section
                    _buildDocumentUploadCard(
                      isDark: isDark,
                      title: 'Driving Licence',
                      icon: Icons.drive_eta,
                      iconAsset: null, // Option to pass a PNG image asset (e.g. 'assets/drivewithuslogo.png')
                      imageFile: _drivingLicenceImage,
                      isLoading: _isUploadingDriving,
                      onPickImage: () => _pickImage('driving'),
                      onUpload: _drivingLicenceImage != null ? () => _uploadImage('driving') : null,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Save Button
              Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5A1F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _savePersonalInformation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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

  Widget _buildDocumentUploadCard({
    required bool isDark,
    required String title,
    required IconData icon,
    String? iconAsset,
    double? iconSize,
    double? iconScale,
    double? iconOffsetX,
    double? iconOffsetY,
    required File? imageFile,
    required bool isLoading,
    required VoidCallback onPickImage,
    VoidCallback? onUpload,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7E9DF),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5A1F).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: AppIconOrImage(
                  icon: icon,
                  imageAsset: iconAsset,
                  iconColor: const Color(0xFFFF5A1F),
                  size: iconSize ?? 20,
                  scale: iconScale ?? 1.0,
                  offsetX: iconOffsetX ?? 0.0,
                  offsetY: iconOffsetY ?? 0.0,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2B1B12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Image Preview or Placeholder
          GestureDetector(
            onTap: onPickImage,
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE5D7C9),
                  style: BorderStyle.solid,
                ),
              ),
              child: imageFile != null
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  imageFile,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              )
                  : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 40,
                    color: Color(0xFFFF5A1F),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap to upload image',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7D6C62),
                    ),
                  ),
                  Text(
                    'JPG, PNG supported',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF9A8B82),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6D6C8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: OutlinedButton(
                    onPressed: onPickImage,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Choose Image',
                      style: TextStyle(color: Color(0xFF2B1B12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5A1F),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ElevatedButton(
                    onPressed: onUpload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Text('Upload'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}