import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _fontSize = 14.0;
  String _themeMode = 'light';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final fontSize = await SettingsService.getFontSize();
    final themeMode = await SettingsService.getThemeMode();
    setState(() {
      _fontSize = fontSize;
      _themeMode = themeMode;
      _isLoading = false;
    });
  }

  Future<void> _saveFontSize(double value) async {
    setState(() {
      _fontSize = value;
    });
    await SettingsService.setFontSize(value);
  }

  Future<void> _saveThemeMode(String value) async {
    setState(() {
      _themeMode = value;
    });
    await SettingsService.setThemeMode(value);
    // Notify parent to rebuild with new theme
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Theme changed. Restart app to see changes.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _resetSettings() async {
      final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: Text('Are you sure you want to reset all settings to default?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await SettingsService.resetSettings();
      await _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings reset to default'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Font Size Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.text_fields, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      const Text(
                        'Font Size',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Current: ${_fontSize.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: _fontSize),
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: _fontSize,
                    min: 12.0,
                    max: 24.0,
                    divisions: 12,
                    label: _fontSize.toStringAsFixed(0),
                    onChanged: _saveFontSize,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Small', style: TextStyle(fontSize: 12)),
                      Text('Large', style: TextStyle(fontSize: 24)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Theme Mode Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.palette, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      const Text(
                        'Theme Mode',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  RadioListTile<String>(
                    title: const Text('Light Mode'),
                    subtitle: const Text('Default light theme'),
                    value: 'light',
                    groupValue: _themeMode,
                    onChanged: (value) => _saveThemeMode(value!),
                  ),
                  RadioListTile<String>(
                    title: const Text('Dark Mode'),
                    subtitle: const Text('Dark theme for low light'),
                    value: 'dark',
                    groupValue: _themeMode,
                    onChanged: (value) => _saveThemeMode(value!),
                  ),
                  RadioListTile<String>(
                    title: const Text('System Default'),
                    subtitle: const Text('Follow device theme'),
                    value: 'system',
                    groupValue: _themeMode,
                    onChanged: (value) => _saveThemeMode(value!),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Reset Button
          Card(
            child: ListTile(
              leading: Icon(Icons.restore, color: Colors.orange[700]),
              title: const Text('Reset to Defaults'),
              subtitle: const Text('Reset all settings to default values'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _resetSettings,
            ),
          ),
        ],
      ),
    );
  }
}

