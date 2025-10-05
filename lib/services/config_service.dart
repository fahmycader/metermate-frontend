import 'dart:convert';
import 'package:flutter/services.dart';

class ConfigService {
  static Map<String, dynamic>? _config;
  static String _environment = 'development';

  static Future<void> initialize() async {
    try {
      final String configString = await rootBundle.loadString('assets/config/ipconfig.json');
      final Map<String, dynamic> config = json.decode(configString);
      _config = config;
    } catch (e) {
      print('Error loading config: $e');
      // Fallback to hardcoded values if config file is not found
      _config = {
        'development': {
          'backend': {
            'ip': '192.168.8.163',
            'port': 3001,
            'baseUrl': 'http://192.168.8.163:3001'
          }
        }
      };
    }
  }

  static void setEnvironment(String environment) {
    _environment = environment;
  }

  static String get backendIp {
    return _config?[_environment]?['backend']?['ip'] ?? '192.168.8.163';
  }

  static int get backendPort {
    return _config?[_environment]?['backend']?['port'] ?? 3001;
  }

  static String get baseUrl {
    return _config?[_environment]?['backend']?['baseUrl'] ?? 'http://192.168.8.163:3001';
  }

  static String get apiUrl {
    return '$baseUrl/api';
  }

  static String get authUrl {
    return '$baseUrl/api/auth';
  }

  static String get jobsUrl {
    return '$baseUrl/api/jobs';
  }

  static String get uploadUrl {
    return '$baseUrl/api/upload';
  }

  static String get housesUrl {
    return '$baseUrl/api/houses';
  }
}
