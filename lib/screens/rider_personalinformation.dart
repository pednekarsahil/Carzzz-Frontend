// File: rider_personalinformation.dart
// Description: Personal information page for riders to upload PAN card and driving licence images

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
    final bool isDark = widget.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111827) : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Personal Information'),
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
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
                  color: isDark ? const Color(0xFF1F2937) : Colors.white,
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
                    Text(
                      'Personal Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Full Name
                    TextFormField(
                      controller: _fullNameController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF3B82F6)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
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
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF3B82F6)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
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
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF3B82F6)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
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
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Address',
                        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF3B82F6)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
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
                  color: isDark ? const Color(0xFF1F2937) : Colors.white,
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
                    Text(
                      'Document Upload',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please upload clear images of your PAN card and Driving Licence for verification',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // PAN Card Section
                    _buildDocumentUploadCard(
                      isDark: isDark,
                      title: 'PAN Card',
                      icon: Icons.credit_card,
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
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _savePersonalInformation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
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
    );
  }

  Widget _buildDocumentUploadCard({
    required bool isDark,
    required String title,
    required IconData icon,
    required File? imageFile,
    required bool isLoading,
    required VoidCallback onPickImage,
    VoidCallback? onUpload,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
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
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF3B82F6), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
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
                color: isDark ? const Color(0xFF1F2937) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
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
                  : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 40,
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to upload $title image',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[500],
                    ),
                  ),
                  Text(
                    'JPG, PNG supported',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
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
                child: OutlinedButton(
                  onPressed: onPickImage,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF3B82F6)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Choose Image',
                    style: TextStyle(color: Color(0xFF3B82F6)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onUpload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
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
            ],
          ),
        ],
      ),
    );
  }
}