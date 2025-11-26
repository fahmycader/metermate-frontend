import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config_service.dart';

class MessagesService {
  static String get _baseUrl => ConfigService.messagesUrl;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<Map<String, dynamic>> getMyMessages() async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};
      final res = await http.get(
        Uri.parse(_baseUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) return {'success': true, 'data': data['data']};
      return {'success': false, 'message': data['message'] ?? 'Failed to fetch messages'};
    } catch (e) {
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  Future<Map<String, dynamic>> markRead(String id) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};
      final res = await http.put(
        Uri.parse('$_baseUrl/$id/read'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) return {'success': true, 'data': data['data']};
      return {'success': false, 'message': data['message'] ?? 'Failed to mark read'};
    } catch (e) {
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  Future<Map<String, dynamic>> deleteMessage(String id) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};
      final res = await http.delete(
        Uri.parse('$_baseUrl/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) return {'success': true, 'data': data};
      return {'success': false, 'message': data['message'] ?? 'Failed to delete message'};
    } catch (e) {
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  Future<Map<String, dynamic>> toggleStar(String id) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};
      final res = await http.put(
        Uri.parse('$_baseUrl/$id/star'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) return {'success': true, 'data': data['data']};
      return {'success': false, 'message': data['message'] ?? 'Failed to star message'};
    } catch (e) {
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  Future<Map<String, dynamic>> pokeAdmin() async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};
      final res = await http.post(
        Uri.parse('$_baseUrl/poke'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 || res.statusCode == 201) return {'success': true, 'data': data};
      return {'success': false, 'message': data['message'] ?? 'Failed to notify admin'};
    } catch (e) {
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }
}

