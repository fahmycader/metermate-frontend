import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationValidationService {
  static const double REQUIRED_RADIUS_METERS = 300.0;
  
  /// Get job coordinates from multiple possible sources
  static Future<Map<String, dynamic>?> getJobCoordinates(Map<String, dynamic> job) async {
    print('🔍 Searching for job coordinates...');
    print('Job data structure: ${job.keys.toList()}');
    
    // Method 1: Try house coordinates
    if (job['house'] != null) {
      final house = job['house'];
      print('🏠 House data: $house');
      
      if (house['latitude'] != null && house['longitude'] != null) {
        print('✅ Found coordinates in house: ${house['latitude']}, ${house['longitude']}');
        return {
          'latitude': house['latitude'].toDouble(),
          'longitude': house['longitude'].toDouble(),
          'source': 'house'
        };
      }
    }
    
    // Method 2: Try address coordinates
    if (job['address'] != null) {
      final address = job['address'];
      print('🏠 Address data: $address');
      
      if (address['latitude'] != null && address['longitude'] != null) {
        print('✅ Found coordinates in address: ${address['latitude']}, ${address['longitude']}');
        return {
          'latitude': address['latitude'].toDouble(),
          'longitude': address['longitude'].toDouble(),
          'source': 'address'
        };
      }
    }
    
    // Method 3: Try location field
    if (job['location'] != null) {
      final location = job['location'];
      print('📍 Location data: $location');
      
      if (location['latitude'] != null && location['longitude'] != null) {
        print('✅ Found coordinates in location: ${location['latitude']}, ${location['longitude']}');
        return {
          'latitude': location['latitude'].toDouble(),
          'longitude': location['longitude'].toDouble(),
          'source': 'location'
        };
      }
    }
    
    // Method 4: Try to get coordinates from address string using geocoding
    String? addressString = buildAddressString(job);
    if (addressString != null) {
      print('🌍 Trying geocoding for address: $addressString');
      try {
        List<Location> locations = await locationFromAddress(addressString);
        if (locations.isNotEmpty) {
          final location = locations.first;
          print('✅ Found coordinates via geocoding: ${location.latitude}, ${location.longitude}');
          return {
            'latitude': location.latitude,
            'longitude': location.longitude,
            'source': 'geocoding'
          };
        }
      } catch (e) {
        print('❌ Geocoding failed: $e');
      }
    }
    
    print('❌ No coordinates found for job');
    return null;
  }
  
  /// Build address string from job data
  static String? buildAddressString(Map<String, dynamic> job) {
    List<String> addressParts = [];
    
    // Try house address first
    if (job['house'] != null) {
      final house = job['house'];
      if (house['address'] != null) addressParts.add(house['address']);
      if (house['city'] != null) addressParts.add(house['city']);
      if (house['county'] != null) addressParts.add(house['county']);
      if (house['postcode'] != null) addressParts.add(house['postcode']);
    }
    
    // If no house address, try job address
    if (addressParts.isEmpty && job['address'] != null) {
      final address = job['address'];
      if (address['street'] != null) addressParts.add(address['street']);
      if (address['city'] != null) addressParts.add(address['city']);
      if (address['state'] != null) addressParts.add(address['state']);
      if (address['zipCode'] != null) addressParts.add(address['zipCode']);
    }
    
    return addressParts.isNotEmpty ? addressParts.join(', ') : null;
  }
  
  /// Calculate distance between two points
  static double calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }
  
  /// Check if user is within required radius of job location
  static Future<Map<String, dynamic>> validateLocation(
    Position userPosition,
    Map<String, dynamic> job,
  ) async {
    print('🔍 Validating location for job: ${job['_id']}');
    print('👤 User position: ${userPosition.latitude}, ${userPosition.longitude}');
    
    // Get job coordinates
    final jobCoords = await getJobCoordinates(job);
    
    if (jobCoords == null) {
      return {
        'isValid': false,
        'distance': 0.0,
        'error': 'Job location coordinates not found',
        'canProceed': false,
      };
    }
    
    // Calculate distance
    final distance = calculateDistance(
      userPosition.latitude,
      userPosition.longitude,
      jobCoords['latitude']!,
      jobCoords['longitude']!,
    );
    
    final isValid = distance <= REQUIRED_RADIUS_METERS;
    
    print('📏 Distance: ${distance.toStringAsFixed(2)}m');
    print('✅ Within radius: $isValid');
    
    return {
      'isValid': isValid,
      'distance': distance,
      'jobCoordinates': jobCoords,
      'canProceed': isValid,
      'message': isValid 
          ? 'You are within the required ${REQUIRED_RADIUS_METERS}m radius'
          : 'You are ${distance.toStringAsFixed(0)}m away. Please move within ${REQUIRED_RADIUS_METERS}m to proceed.',
    };
  }
  
  /// Get current user position with error handling
  static Future<Position?> getCurrentPosition() async {
    try {
      print('📍 Getting current position...');
      
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('❌ Location permission denied');
          return null;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        print('❌ Location permission permanently denied');
        return null;
      }
      
      // Get position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      print('✅ Current position: ${position.latitude}, ${position.longitude}');
      return position;
      
    } catch (e) {
      print('❌ Error getting current position: $e');
      return null;
    }
  }
  
  /// Manual location input fallback
  static Future<Map<String, dynamic>?> getManualLocation() async {
    // This would be called from a dialog where user can input coordinates manually
    // For now, return null - this can be implemented with a dialog
    return null;
  }
}
