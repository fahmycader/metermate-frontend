import 'package:flutter/material.dart';

class LocationInputDialog extends StatefulWidget {
  final String jobAddress;
  
  const LocationInputDialog({super.key, required this.jobAddress});

  @override
  State<LocationInputDialog> createState() => _LocationInputDialogState();
}

class _LocationInputDialogState extends State<LocationInputDialog> {
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  bool _isValidating = false;

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  bool _isValidCoordinate(String value) {
    final double? coord = double.tryParse(value);
    if (coord == null) return false;
    
    // Check if it's a valid latitude (-90 to 90) or longitude (-180 to 180)
    return (coord >= -90 && coord <= 90) || (coord >= -180 && coord <= 180);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manual Location Input'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Job Address: ${widget.jobAddress}',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          const Text(
            'Enter the job location coordinates manually:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _latitudeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Latitude',
              hintText: 'e.g., 51.5074',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _longitudeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Longitude',
              hintText: 'e.g., -0.1278',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tip: You can get coordinates from Google Maps by right-clicking on the location.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _canProceed() ? _proceed : null,
          child: _isValidating 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Use These Coordinates'),
        ),
      ],
    );
  }

  bool _canProceed() {
    final lat = _latitudeController.text.trim();
    final lng = _longitudeController.text.trim();
    
    if (lat.isEmpty || lng.isEmpty) return false;
    
    final latValue = double.tryParse(lat);
    final lngValue = double.tryParse(lng);
    
    if (latValue == null || lngValue == null) return false;
    
    // Check if latitude is valid (-90 to 90)
    if (latValue < -90 || latValue > 90) return false;
    
    // Check if longitude is valid (-180 to 180)
    if (lngValue < -180 || lngValue > 180) return false;
    
    return true;
  }

  void _proceed() {
    final lat = double.parse(_latitudeController.text.trim());
    final lng = double.parse(_longitudeController.text.trim());
    
    Navigator.of(context).pop({
      'latitude': lat,
      'longitude': lng,
      'source': 'manual'
    });
  }
}
