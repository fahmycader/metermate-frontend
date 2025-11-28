import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config_service.dart';

class JobService {
  static Future<String> get _baseUrl async => '${await ConfigService.getBaseUrl()}/api/jobs';

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

      final baseUrl = await _baseUrl;
      final response = await http.get(
        Uri.parse(baseUrl),
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

      final baseUrl = await _baseUrl;
      final uri = Uri.parse('$baseUrl/assigned').replace(queryParameters: queryParams);

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

      final baseUrl = await _baseUrl;
      final uri = Uri.parse('$baseUrl/today').replace(queryParameters: queryParams);

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

  Future<Map<String, dynamic>> getTodaysJobsGeo({String? status, String? jobType, String? priority, double? userLatitude, double? userLongitude}) async {
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
      if (userLatitude != null) queryParams['userLatitude'] = userLatitude.toString();
      if (userLongitude != null) queryParams['userLongitude'] = userLongitude.toString();

      final baseUrl = await _baseUrl;
      final uri = Uri.parse('$baseUrl/today-geo').replace(queryParameters: queryParams);

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
        return {'success': false, 'message': responseData['message'] ?? 'Failed to get today\'s jobs geo'};
      }
    } catch (e) {
      print('Get Today\'s Jobs Geo Error: $e');
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

      final baseUrl = await _baseUrl;
      final uri = Uri.parse('$baseUrl/my-count').replace(queryParameters: queryParams);

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
        Uri.parse('${await _baseUrl}/$jobId'),
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
        Uri.parse('${await _baseUrl}/$jobId'),
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

  Future<Map<String, dynamic>> completeJob(String jobId, Map<String, dynamic> completionData) async {
    try {
      String? token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.put(
        Uri.parse('${await _baseUrl}/$jobId/complete'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(completionData),
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': responseData};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to complete job'};
      }
    } catch (e) {
      print('Complete Job Error: $e');
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }
}
