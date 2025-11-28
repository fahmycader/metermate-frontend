import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config_service.dart';

class MeterReadingService {
  static Future<String> get _baseUrl async => '${await ConfigService.getBaseUrl()}/api/meter-readings';

  Future<String?> _getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<Map<String, dynamic>> createMeterReading(Map<String, dynamic> readingData) async {
    try {
      String? token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.post(
        Uri.parse(await _baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(readingData),
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return {'success': true, 'data': responseData['data']};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to create meter reading'};
      }
    } catch (e) {
      print('Create Meter Reading Error: $e');
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  Future<Map<String, dynamic>> getMeterReadings({int page = 1, int limit = 10, String? date}) async {
    try {
      String? token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      Map<String, String> queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (date != null && date.isNotEmpty) {
        queryParams['date'] = date;
      }

      final baseUrl = await _baseUrl;
      final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': responseData['data'], 'pagination': responseData['pagination']};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to get meter readings'};
      }
    } catch (e) {
      print('Get Meter Readings Error: $e');
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  Future<Map<String, dynamic>> getTodaysMeterReadings() async {
    try {
      String? token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.get(
        Uri.parse('${await _baseUrl}/today'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': responseData['data'], 'count': responseData['count']};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to get today\'s meter readings'};
      }
    } catch (e) {
      print('Get Today\'s Meter Readings Error: $e');
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  Future<Map<String, dynamic>> getMeterReading(String readingId) async {
    try {
      String? token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.get(
        Uri.parse('${await _baseUrl}/$readingId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': responseData['data']};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to get meter reading'};
      }
    } catch (e) {
      print('Get Meter Reading Error: $e');
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  Future<Map<String, dynamic>> updateMeterReading(String readingId, Map<String, dynamic> readingData) async {
    try {
      String? token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.put(
        Uri.parse('${await _baseUrl}/$readingId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(readingData),
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': responseData['data']};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to update meter reading'};
      }
    } catch (e) {
      print('Update Meter Reading Error: $e');
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }
}
