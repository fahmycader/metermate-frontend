import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/meter_reading_service.dart';
import '../services/job_service.dart';
import '../services/location_service.dart';
import '../services/camera_service.dart';
import '../services/location_validation_service.dart';
import '../widgets/location_input_dialog.dart';

class MeterReadingScreen extends StatefulWidget {
  final Map<String, dynamic> job;
  
  const MeterReadingScreen({super.key, required this.job});

  @override
  State<MeterReadingScreen> createState() => _MeterReadingScreenState();
}

class _MeterReadingScreenState extends State<MeterReadingScreen> {
  final MeterReadingService _meterReadingService = MeterReadingService();
  final LocationService _locationService = LocationService();
  final CameraService _cameraService = CameraService();
  
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, File?> _photos = {};
  
  String _customerRead = 'Yes';
  bool _isSubmitting = false;
  Position? _currentPosition;
  Map<String, dynamic>? _locationValidation;
  bool _isValidatingLocation = false;

  final List<String> _customerReadOptions = [
    'Yes',
    'No',
    'No access',
    'Refuse access',
    'Failed first visit',
    'Meter blocked',
    'Unable to locate the meter',
    'Unmanned',
    'Demolished',
    'Unsafe premises',
    'Meter inspected',
    'Risk assessment'
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _validateLocation();
  }

  Future<void> _validateLocation() async {
    setState(() => _isValidatingLocation = true);
    
    try {
      // Get current position
      final position = await LocationValidationService.getCurrentPosition();
      if (position == null) {
        setState(() {
          _locationValidation = {
            'isValid': false,
            'distance': 0.0,
            'error': 'Unable to get current location. Please enable location services.',
            'canProceed': false,
          };
        });
        return;
      }
      
      setState(() => _currentPosition = position);
      
      // Validate location
      final validation = await LocationValidationService.validateLocation(position, widget.job);
      setState(() => _locationValidation = validation);
      
    } catch (e) {
      print('Error validating location: $e');
      setState(() {
        _locationValidation = {
          'isValid': false,
          'distance': 0.0,
          'error': 'Error validating location: $e',
          'canProceed': false,
        };
      });
    } finally {
      setState(() => _isValidatingLocation = false);
    }
  }

  Future<void> _showManualLocationDialog() async {
    final addressString = LocationValidationService.buildAddressString(widget.job) ?? 'Unknown Address';
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => LocationInputDialog(jobAddress: addressString),
    );
    
    if (result != null) {
      // Use manual coordinates for validation
      final position = _currentPosition;
      if (position != null) {
        final distance = LocationValidationService.calculateDistance(
          position.latitude,
          position.longitude,
          result['latitude'],
          result['longitude'],
        );
        
        final isValid = distance <= LocationValidationService.REQUIRED_RADIUS_METERS;
        
        setState(() {
          _locationValidation = {
            'isValid': isValid,
            'distance': distance,
            'jobCoordinates': result,
            'canProceed': isValid,
            'message': isValid 
                ? 'You are within the required ${LocationValidationService.REQUIRED_RADIUS_METERS}m radius'
                : 'You are ${distance.toStringAsFixed(0)}m away. Please move within ${LocationValidationService.REQUIRED_RADIUS_METERS}m to proceed.',
          };
        });
      }
    }
  }

  void _initializeControllers() {
    _controllers['sup'] = TextEditingController();
    _controllers['jt'] = TextEditingController();
    _controllers['cust'] = TextEditingController();
    _controllers['address1'] = TextEditingController(text: widget.job['address']?['street'] ?? '');
    _controllers['address2'] = TextEditingController();
    _controllers['address3'] = TextEditingController();
    _controllers['noR'] = TextEditingController();
    _controllers['rc'] = TextEditingController();
    _controllers['makeOfMeter'] = TextEditingController();
    _controllers['model'] = TextEditingController();
    _controllers['regID1'] = TextEditingController();
    _controllers['reg1'] = TextEditingController();
    _controllers['notes'] = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Meter Reading'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: _validateLocation,
            tooltip: 'Refresh Location',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Job Information Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.work, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Job Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _viewJobLocation,
                            icon: const Icon(Icons.map, size: 16),
                            label: const Text('View Map'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('Job ID', widget.job['_id']),
                      _buildInfoRow('Job Type', widget.job['jobType']?.toString().toUpperCase() ?? ''),
                      _buildInfoRow('Priority', widget.job['priority']?.toString().toUpperCase() ?? ''),
                      _buildInfoRow('Status', widget.job['status']?.toString().toUpperCase() ?? ''),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Location Status Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (_isValidatingLocation)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Icon(
                              _locationValidation?['isValid'] == true ? Icons.check_circle : Icons.warning,
                              color: _locationValidation?['isValid'] == true ? Colors.green[700] : Colors.orange[700],
                            ),
                          const SizedBox(width: 8),
                          Text(
                            'Location Status',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _locationValidation?['isValid'] == true ? Colors.green[700] : Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_isValidatingLocation)
                        const Text('Validating location...')
                      else if (_locationValidation != null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _locationValidation!['error'] != null
                                        ? _locationValidation!['error']
                                        : 'Distance to Job: ${_locationValidation!['distance'].toStringAsFixed(0)} meters',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: _locationValidation!['isValid'] == true ? Colors.green[600] : Colors.orange[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _locationValidation!['message'] ?? 'Location validation failed',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _locationValidation!['isValid'] == true ? Colors.green[600] : Colors.orange[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _viewJobLocation,
                                  icon: const Icon(Icons.map, size: 16),
                                  label: const Text('Google Maps'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: _showManualLocationDialog,
                                  icon: const Icon(Icons.edit_location, size: 16),
                                  label: const Text('Manual'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ] else
                        const Text('Location validation not available'),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Customer Information Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, color: Colors.green[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Customer Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField('Sup', 'sup', Icons.badge),
                      const SizedBox(height: 12),
                      _buildTextField('JT', 'jt', Icons.work_outline),
                      const SizedBox(height: 12),
                      _buildTextField('Cust', 'cust', Icons.person_outline),
                      const SizedBox(height: 12),
                      _buildTextField('Address 1', 'address1', Icons.location_on),
                      const SizedBox(height: 12),
                      _buildTextField('Address 2', 'address2', Icons.location_city),
                      const SizedBox(height: 12),
                      _buildTextField('Address 3', 'address3', Icons.location_city),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Customer Read Status Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Customer Read Status',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _customerRead,
                        decoration: const InputDecoration(
                          labelText: 'Customer Read?',
                          border: OutlineInputBorder(),
                        ),
                        items: _customerReadOptions.map((String option) {
                          return DropdownMenuItem<String>(
                            value: option,
                            child: Text(option),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _customerRead = newValue!;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select customer read status';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Meter Information Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.speed, color: Colors.purple[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Meter Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField('NoR', 'noR', Icons.numbers),
                      const SizedBox(height: 12),
                      _buildTextField('RC', 'rc', Icons.code),
                      const SizedBox(height: 12),
                      _buildTextField('Make of Meter', 'makeOfMeter', Icons.build),
                      const SizedBox(height: 12),
                      _buildTextField('Model', 'model', Icons.model_training),
                      const SizedBox(height: 12),
                      _buildTextField('Reg ID1', 'regID1', Icons.confirmation_number),
                      const SizedBox(height: 12),
                      _buildTextField('Reg 1', 'reg1', Icons.confirmation_number),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Photos Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.camera_alt, color: Colors.red[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Meter Photos',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _takePhoto,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Take Photo'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[700],
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          if (_photos['meter'] != null) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _viewPhoto,
                                icon: const Icon(Icons.visibility),
                                label: const Text('View'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Notes Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.note, color: Colors.teal[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Additional Notes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _controllers['notes'],
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          border: OutlineInputBorder(),
                          hintText: 'Enter any additional notes...',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_isSubmitting || _locationValidation?['canProceed'] != true) ? null : _submitMeterReading,
                  icon: _isSubmitting 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                  label: Text(_isSubmitting 
                      ? 'Submitting...' 
                      : _locationValidation?['canProceed'] != true
                          ? (_locationValidation?['error'] != null
                              ? 'Location Error - Use Manual Input'
                              : 'You are ${_locationValidation?['distance']?.toStringAsFixed(0) ?? '0'}m away from location. Please move closer and try again.')
                          : 'Submit Meter Reading'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _locationValidation?['canProceed'] == true ? Colors.green[700] : Colors.grey[400],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String key, IconData icon) {
    return TextFormField(
      controller: _controllers[key],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }

  Future<void> _takePhoto() async {
    try {
      File? photo = await _cameraService.takePhoto();
      if (photo != null) {
        setState(() {
          _photos['meter'] = photo;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewPhoto() {
    if (_photos['meter'] != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Meter Photo'),
          content: Image.file(_photos['meter']!),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _viewJobLocation() async {
    try {
      // Get job coordinates
      final jobCoords = await LocationValidationService.getJobCoordinates(widget.job);
      
      if (jobCoords == null) {
        // If no coordinates found, show manual input dialog
        await _showManualLocationDialog();
        return;
      }
      
      final lat = jobCoords['latitude'];
      final lng = jobCoords['longitude'];
      final addressString = LocationValidationService.buildAddressString(widget.job) ?? 'Job Location';
      
      // Create Google Maps URL
      final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      final appleMapsUrl = 'https://maps.apple.com/?q=$lat,$lng';
      
      // Check if we can launch URLs
      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        // Show dialog to choose map app
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Open Job Location'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Job Address: $addressString'),
                    const SizedBox(height: 16),
                    const Text('Choose your preferred map app:'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.map),
                    label: const Text('Google Maps'),
                  ),
                  if (Platform.isIOS)
                    ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await launchUrl(Uri.parse(appleMapsUrl), mode: LaunchMode.externalApplication);
                      },
                      icon: const Icon(Icons.map),
                      label: const Text('Apple Maps'),
                    ),
                ],
              );
            },
          );
        }
      } else {
        // Fallback: show coordinates in a dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Job Location'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Address: $addressString'),
                    const SizedBox(height: 8),
                    Text('Coordinates: $lat, $lng'),
                    const SizedBox(height: 16),
                    const Text(
                      'Copy these coordinates and paste them into your map app to navigate to the job location.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              );
            },
          );
        }
      }
    } catch (e) {
      print('Error opening job location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening map: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitMeterReading() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check location validation
    if (_locationValidation?['canProceed'] != true) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Location Validation'),
              content: Text(
                _locationValidation?['message'] ?? 'You must be within 300 meters to complete this job.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Upload photo if taken
      List<String> photoUrls = [];
      if (_photos['meter'] != null) {
        String? url = await _cameraService.uploadPhoto(
          _photos['meter']!,
          widget.job['_id'],
          'meter',
        );
        if (url != null) {
          photoUrls.add(url);
        }
      }

      // Prepare meter reading data
      Map<String, dynamic> readingData = {
        'jobId': widget.job['_id'],
        'sup': _controllers['sup']!.text,
        'jt': _controllers['jt']!.text,
        'cust': _controllers['cust']!.text,
        'address1': _controllers['address1']!.text,
        'address2': _controllers['address2']!.text,
        'address3': _controllers['address3']!.text,
        'customerRead': _customerRead,
        'noR': _controllers['noR']!.text,
        'rc': _controllers['rc']!.text,
        'makeOfMeter': _controllers['makeOfMeter']!.text,
        'model': _controllers['model']!.text,
        'regID1': _controllers['regID1']!.text,
        'reg1': _controllers['reg1']!.text,
        'photos': photoUrls,
        'notes': _controllers['notes']!.text,
      };

      // Add location if available
      if (_currentPosition != null) {
        readingData['location'] = {
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
        };
      }

      // Submit meter reading and complete the job
      final JobService jobService = JobService();
      
      // Prepare job completion data with location and distance
      Map<String, dynamic> jobCompletionData = {
        'status': 'completed',
        'meterReadings': readingData,
        'photos': photoUrls,
        'location': _currentPosition != null ? {
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
        } : null,
        'notes': _controllers['notes']!.text,
      };

      // Add distance calculation if we have location validation data
      if (_locationValidation?['jobCoordinates'] != null && _currentPosition != null) {
        final jobCoords = _locationValidation!['jobCoordinates'];
        final distance = _locationValidation!['distance'];
        
        jobCompletionData['distanceTraveled'] = distance / 1000; // Convert to kilometers
        jobCompletionData['endLocation'] = {
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
          'timestamp': DateTime.now().toIso8601String(),
        };
      }

      // Complete the job using the new endpoint
      final result = await jobService.completeJob(widget.job['_id'], jobCompletionData);
      
      if (result['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Job completed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true); // Return true to indicate success
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting meter reading: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
