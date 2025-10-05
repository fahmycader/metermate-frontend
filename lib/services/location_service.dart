import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config_service.dart';

class LocationService {
  static String get _baseUrl => ConfigService.jobsUrl;
  
  StreamSubscription<Position>? _positionStream;
  Position? _currentPosition;
  List<Position> _locationHistory = [];
  Timer? _locationTimer;
  
  Future<String?> _getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<bool> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    
    return true;
  }

  Future<Position?> getCurrentLocation() async {
    try {
      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      _currentPosition = position;
      return position;
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  double calculateDistance(Position start, Position end) {
    return Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    ) / 1000; // Convert to kilometers
  }

  double calculateDistanceToDestination(Position current, double destLat, double destLng) {
    return Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      destLat,
      destLng,
    ) / 1000; // Convert to kilometers
  }

  Future<bool> isWithinRange(double destLat, double destLng, double rangeKm) async {
    Position? current = await getCurrentLocation();
    if (current == null) return false;
    
    double distance = calculateDistanceToDestination(current, destLat, destLng);
    return distance <= rangeKm;
  }

  void startLocationTracking(String jobId) {
    _locationHistory.clear();
    
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) {
      _currentPosition = position;
      _locationHistory.add(position);
      
      // Send location update to server every 30 seconds
      _locationTimer?.cancel();
      _locationTimer = Timer(const Duration(seconds: 30), () {
        _sendLocationUpdate(jobId, position);
      });
    });
  }

  void stopLocationTracking() {
    _positionStream?.cancel();
    _locationTimer?.cancel();
    _locationHistory.clear();
  }

  Future<void> _sendLocationUpdate(String jobId, Position position) async {
    try {
      String? token = await _getToken();
      if (token == null) return;

      await http.post(
        Uri.parse('$_baseUrl/$jobId/location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      print('Error sending location update: $e');
    }
  }

  Future<Map<String, dynamic>> startJob(String jobId, Position startPosition) async {
    try {
      String? token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/$jobId/start'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'startLocation': {
            'latitude': startPosition.latitude,
            'longitude': startPosition.longitude,
            'timestamp': DateTime.now().toIso8601String(),
          },
        }),
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        startLocationTracking(jobId);
        return {'success': true, 'data': responseData};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to start job'};
      }
    } catch (e) {
      print('Start Job Error: $e');
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  Future<Map<String, dynamic>> completeJob(String jobId, Position endPosition, Map<String, dynamic> readings, List<String> photoUrls) async {
    try {
      String? token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Calculate total distance traveled
      double totalDistance = 0;
      if (_locationHistory.length > 1) {
        for (int i = 1; i < _locationHistory.length; i++) {
          totalDistance += calculateDistance(_locationHistory[i-1], _locationHistory[i]);
        }
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/$jobId/complete'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'endLocation': {
            'latitude': endPosition.latitude,
            'longitude': endPosition.longitude,
            'timestamp': DateTime.now().toIso8601String(),
          },
          'distanceTraveled': totalDistance,
          'locationHistory': _locationHistory.map((pos) => {
            'latitude': pos.latitude,
            'longitude': pos.longitude,
            'timestamp': DateTime.now().toIso8601String(),
          }).toList(),
          'meterReadings': readings,
          'photoUrls': photoUrls,
        }),
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        stopLocationTracking();
        return {'success': true, 'data': responseData};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to complete job'};
      }
    } catch (e) {
      print('Complete Job Error: $e');
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  Future<Map<String, dynamic>> getJobLocation(String jobId) async {
    try {
      String? token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/$jobId/location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': responseData};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to get job location'};
      }
    } catch (e) {
      print('Get Job Location Error: $e');
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }
}
