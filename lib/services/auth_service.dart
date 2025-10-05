import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config_service.dart';

class AuthService {
  static String get _baseUrl => ConfigService.authUrl; 

  // For physical device, replace 10.0.2.2 with your computer's IP address

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        // Save user data and token
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', responseData['token']);
        await prefs.setString('userData', jsonEncode(responseData));
        await prefs.setBool('isLoggedIn', true);
        return {'success': true, 'data': responseData};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Login failed'};
      }
    } catch (e) {
      print('Login Error: $e');
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  Future<Map<String, dynamic>> register(String username, String password, {
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? employeeId,
    String? department,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username, 
          'password': password,
          'firstName': firstName ?? '',
          'lastName': lastName ?? '',
          'email': email ?? '',
          'phone': phone ?? '',
          'employeeId': employeeId ?? '',
          'department': department ?? '',
        }),
      );
      
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 201) {
        // Save user data and token
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', responseData['token']);
        await prefs.setString('userData', jsonEncode(responseData));
        await prefs.setBool('isLoggedIn', true);
        return {'success': true, 'data': responseData};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Registration failed'};
      }
    } catch (e) {
      print('Register Error: $e');
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<bool> isLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<Map<String, dynamic>?> getUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userDataString = prefs.getString('userData');
    if (userDataString != null) {
      return jsonDecode(userDataString);
    }
    return null;
  }

  Future<String?> getUsername() async {
    Map<String, dynamic>? userData = await getUserData();
    return userData?['username'];
  }

  Future<String?> getFullName() async {
    Map<String, dynamic>? userData = await getUserData();
    if (userData != null) {
      String firstName = userData['firstName'] ?? '';
      String lastName = userData['lastName'] ?? '';
      if (firstName.isNotEmpty && lastName.isNotEmpty) {
        return '$firstName $lastName';
      } else if (firstName.isNotEmpty) {
        return firstName;
      } else if (lastName.isNotEmpty) {
        return lastName;
      }
    }
    return null;
  }

  Future<String?> getEmployeeId() async {
    Map<String, dynamic>? userData = await getUserData();
    return userData?['employeeId'];
  }

  Future<String?> getDepartment() async {
    Map<String, dynamic>? userData = await getUserData();
    return userData?['department'];
  }

  Future<int> getJobsCompleted() async {
    Map<String, dynamic>? userData = await getUserData();
    return userData?['jobsCompleted'] ?? 0;
  }

  Future<double> getWeeklyPerformance() async {
    Map<String, dynamic>? userData = await getUserData();
    return (userData?['weeklyPerformance'] ?? 0).toDouble();
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      String? token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        // Update stored user data
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('userData', jsonEncode(responseData));
        return {'success': true, 'data': responseData};
      } else {
        return {'success': false, 'message': responseData['message'] ?? 'Failed to get profile'};
      }
    } catch (e) {
      print('Get Profile Error: $e');
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }
} 