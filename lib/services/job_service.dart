import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class JobService {
  static const String _baseIp = '192.168.8.163';
  static const String _baseUrl = 'http://$_baseIp:3001/api/jobs';

  Future<String?> _getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<Map<String, dynamic>> getJobs() async {
    try {
      String? token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.get(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': responseData};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to get jobs'};
      }
    } catch (e) {
      print('Get Jobs Error: $e');
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  Future<Map<String, dynamic>> getAssignedJobs({String? status, String? jobType, String? priority}) async {
    try {
      String? token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Build query parameters
      Map<String, String> queryParams = {};
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (jobType != null && jobType.isNotEmpty) queryParams['jobType'] = jobType;
      if (priority != null && priority.isNotEmpty) queryParams['priority'] = priority;

      final uri = Uri.parse('$_baseUrl/assigned').replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': responseData};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to get assigned jobs'};
      }
    } catch (e) {
      print('Get Assigned Jobs Error: $e');
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  Future<Map<String, dynamic>> getTodaysJobs({String? status, String? jobType, String? priority}) async {
    try {
      String? token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Build query parameters
      Map<String, String> queryParams = {};
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (jobType != null && jobType.isNotEmpty) queryParams['jobType'] = jobType;
      if (priority != null && priority.isNotEmpty) queryParams['priority'] = priority;

      final uri = Uri.parse('$_baseUrl/today').replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': responseData};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to get today\'s jobs'};
      }
    } catch (e) {
      print('Get Today\'s Jobs Error: $e');
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  Future<Map<String, dynamic>> getMyJobCount({String? status, String? jobType, String? priority, String? dateRange}) async {
    try {
      String? token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      // Build query parameters
      Map<String, String> queryParams = {};
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (jobType != null && jobType.isNotEmpty) queryParams['jobType'] = jobType;
      if (priority != null && priority.isNotEmpty) queryParams['priority'] = priority;
      if (dateRange != null && dateRange.isNotEmpty) queryParams['dateRange'] = dateRange;

      final uri = Uri.parse('$_baseUrl/my-count').replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': responseData};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to get job count'};
      }
    } catch (e) {
      print('Get My Job Count Error: $e');
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  Future<Map<String, dynamic>> updateJobStatus(String jobId, String status) async {
    try {
      String? token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/$jobId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': status}),
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': responseData};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to update job'};
      }
    } catch (e) {
      print('Update Job Error: $e');
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  Future<Map<String, dynamic>> submitMeterReading(String jobId, Map<String, dynamic> readings) async {
    try {
      String? token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/$jobId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'status': 'completed',
          'meterReadings': readings,
          'completedDate': DateTime.now().toIso8601String(),
        }),
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': responseData};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to submit reading'};
      }
    } catch (e) {
      print('Submit Reading Error: $e');
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }
}
