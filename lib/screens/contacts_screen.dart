import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/settings_service.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  double _fontSize = 14.0;
  
  // Important contacts - UK contact numbers and email addresses
  final List<Map<String, String>> _contacts = [
    {
      'name': 'Emergency Contact',
      'phone': '+44 20 7946 0958',
      'email': 'emergency@metermate.co.uk',
      'role': 'Emergency',
    },
    {
      'name': 'Support Team',
      'phone': '+44 20 7946 0959',
      'email': 'support@metermate.co.uk',
      'role': 'Technical Support',
    },
    {
      'name': 'Admin Office',
      'phone': '+44 20 7946 0960',
      'email': 'admin@metermate.co.uk',
      'role': 'Administration',
    },
    {
      'name': 'Dispatch',
      'phone': '+44 20 7946 0961',
      'email': 'dispatch@metermate.co.uk',
      'role': 'Job Dispatch',
    },
    {
      'name': 'Operations Manager',
      'phone': '+44 20 7946 0962',
      'email': 'operations@metermate.co.uk',
      'role': 'Operations',
    },
    {
      'name': 'Customer Service',
      'phone': '+44 800 123 4567',
      'email': 'customerservice@metermate.co.uk',
      'role': 'Customer Service',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadFontSize();
  }

  Future<void> _loadFontSize() async {
    final fontSize = await SettingsService.getFontSize();
    setState(() {
      _fontSize = fontSize;
    });
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot make phone call'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot send email'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Important Contacts',
                          style: TextStyle(
                            fontSize: _fontSize + 4,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to call or send email',
                          style: TextStyle(
                            fontSize: _fontSize,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Contacts list
          ..._contacts.map((contact) => _buildContactCard(contact)),
        ],
      ),
    );
  }

  Widget _buildContactCard(Map<String, String> contact) {
    final name = contact['name'] ?? 'Unknown';
    final phone = contact['phone'] ?? '';
    final email = contact['email'] ?? '';
    final role = contact['role'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.blue[700],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      name[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: _fontSize + 6,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: _fontSize + 2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (role.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          role,
                          style: TextStyle(
                            fontSize: _fontSize - 1,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            
            // Phone
            if (phone.isNotEmpty)
              InkWell(
                onTap: () => _makePhoneCall(phone),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      FaIcon(
                        FontAwesomeIcons.phone,
                        color: Colors.green[700],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          phone,
                          style: TextStyle(
                            fontSize: _fontSize,
                            color: Colors.blue[700],
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey[400]),
                    ],
                  ),
                ),
              ),
            
            // Email
            if (email.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _sendEmail(email),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      FaIcon(
                        FontAwesomeIcons.envelope,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          email,
                          style: TextStyle(
                            fontSize: _fontSize,
                            color: Colors.blue[700],
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey[400]),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

