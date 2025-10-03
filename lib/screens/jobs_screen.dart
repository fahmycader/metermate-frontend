import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/job_service.dart';
import '../services/auth_service.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  final JobService _jobService = JobService();
  final AuthService _authService = AuthService();
  List<dynamic> _jobs = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadJobs();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    super.dispose();
  }

  void _startAutoRefresh() {
    // Auto-refresh every 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _loadJobs();
        _startAutoRefresh(); // Schedule next refresh
      }
    });
  }

  void _stopAutoRefresh() {
    // This will be called when the widget is disposed
  }

  Future<void> _loadUserData() async {
    final userData = await _authService.getUserData();
    setState(() {
      _userData = userData;
    });
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    final result = await _jobService.getAssignedJobs();
    if (result['success']) {
      setState(() {
        _jobs = result['data']['jobs'] ?? [];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateJobStatus(String jobId, String status) async {
    final result = await _jobService.updateJobStatus(jobId, status);
    if (result['success']) {
      _loadJobs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Job status updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<dynamic> get _filteredJobs {
    if (_selectedFilter == 'all') return _jobs;
    return _jobs.where((job) => job['status'] == _selectedFilter).toList();
  }

  String _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return 'green';
      case 'in_progress':
        return 'blue';
      case 'cancelled':
        return 'red';
      default:
        return 'yellow';
    }
  }

  String _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return 'red';
      case 'medium':
        return 'yellow';
      default:
        return 'green';
    }
  }

  String _getJobTypeIcon(String jobType) {
    switch (jobType) {
      case 'electricity':
        return '⚡';
      case 'gas':
        return '🔥';
      case 'water':
        return '💧';
      default:
        return '📋';
    }
  }

  Color _getJobTypeColor(String jobType) {
    switch (jobType) {
      case 'electricity':
        return Colors.amber[700]!;
      case 'gas':
        return Colors.orange[700]!;
      case 'water':
        return Colors.blue[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = _userData?['firstName'] != null && _userData?['lastName'] != null
        ? '${_userData!['firstName']} ${_userData!['lastName']}'
        : _userData?['username'] ?? 'User';
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('My Jobs'),
            Text(
              userName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadJobs,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('all', 'All'),
                        const SizedBox(width: 8),
                        _buildFilterChip('pending', 'Pending'),
                        const SizedBox(width: 8),
                        _buildFilterChip('in_progress', 'In Progress'),
                        const SizedBox(width: 8),
                        _buildFilterChip('completed', 'Completed'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Jobs list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredJobs.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _loadJobs,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.work_outline, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No jobs found',
                                style: TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Pull down to refresh',
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadJobs,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredJobs.length,
                          itemBuilder: (context, index) {
                            final job = _filteredJobs[index];
                            return _buildJobCard(job);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: Colors.blue[100],
      checkmarkColor: Colors.blue[700],
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final address = job['address'];
    final assignedTo = job['assignedTo'];
    final status = job['status'];
    final priority = job['priority'];
    final jobType = job['jobType'];
    final scheduledDate = DateTime.parse(job['scheduledDate']);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _getJobTypeIcon(jobType),
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            jobType.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getJobTypeColor(jobType),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        address['street'] ?? 'Unknown Address',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${address['city']}, ${address['state']} ${address['zipCode']}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status) == 'green' ? Colors.green[100] :
                               _getStatusColor(status) == 'blue' ? Colors.blue[100] :
                               _getStatusColor(status) == 'red' ? Colors.red[100] :
                               Colors.yellow[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(status) == 'green' ? Colors.green[800] :
                                 _getStatusColor(status) == 'blue' ? Colors.blue[800] :
                                 _getStatusColor(status) == 'red' ? Colors.red[800] :
                                 Colors.yellow[800],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(priority) == 'red' ? Colors.red[100] :
                               _getPriorityColor(priority) == 'yellow' ? Colors.yellow[100] :
                               Colors.green[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        priority.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getPriorityColor(priority) == 'red' ? Colors.red[800] :
                                 _getPriorityColor(priority) == 'yellow' ? Colors.yellow[800] :
                                 Colors.green[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const FaIcon(FontAwesomeIcons.clock, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Scheduled: ${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year} at ${scheduledDate.hour.toString().padLeft(2, '0')}:${scheduledDate.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const FaIcon(FontAwesomeIcons.user, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Assigned to: ${assignedTo['firstName']} ${assignedTo['lastName']}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            if (job['notes'] != null && job['notes'].isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const FaIcon(FontAwesomeIcons.noteSticky, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      job['notes'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                if (status == 'pending') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateJobStatus(job['_id'], 'in_progress'),
                      icon: const FaIcon(FontAwesomeIcons.play, size: 16),
                      label: const Text('Start Work'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (status == 'in_progress') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showMeterReadingDialog(job),
                      icon: const FaIcon(FontAwesomeIcons.check, size: 16),
                      label: const Text('Complete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showMapDialog(address),
                    icon: const FaIcon(FontAwesomeIcons.mapLocationDot, size: 16),
                    label: const Text('View Map'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showMeterReadingDialog(Map<String, dynamic> job) {
    final jobType = job['jobType'] ?? 'all';
    
    showDialog(
      context: context,
      builder: (context) => MeterReadingDialog(
        job: job,
        meterType: jobType,
        onComplete: (readings) async {
          final result = await _jobService.submitMeterReading(job['_id'], readings);
          if (result['success']) {
            _loadJobs();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Meter reading submitted successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result['message']),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showMapDialog(Map<String, dynamic> address) {
    showDialog(
      context: context,
      builder: (context) => MapDialog(address: address),
    );
  }
}

class MeterReadingDialog extends StatefulWidget {
  final Map<String, dynamic> job;
  final String meterType;
  final Function(Map<String, dynamic>) onComplete;

  const MeterReadingDialog({
    super.key,
    required this.job,
    required this.meterType,
    required this.onComplete,
  });

  @override
  State<MeterReadingDialog> createState() => _MeterReadingDialogState();
}

class _MeterReadingDialogState extends State<MeterReadingDialog> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    if (widget.meterType == 'all' || widget.meterType == 'electricity') {
      _controllers['electric'] = TextEditingController();
    }
    if (widget.meterType == 'all' || widget.meterType == 'gas') {
      _controllers['gas'] = TextEditingController();
    }
    if (widget.meterType == 'all' || widget.meterType == 'water') {
      _controllers['water'] = TextEditingController();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Submit Meter Reading'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Address: ${widget.job['address']['street']}'),
          const SizedBox(height: 16),
          ..._controllers.entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextField(
              controller: entry.value,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '${entry.key.toUpperCase()} Reading',
                border: const OutlineInputBorder(),
              ),
            ),
          )),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final readings = <String, dynamic>{};
            for (final entry in _controllers.entries) {
              if (entry.value.text.isNotEmpty) {
                readings[entry.key] = double.tryParse(entry.value.text) ?? 0;
              }
            }
            widget.onComplete(readings);
            Navigator.of(context).pop();
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

class MapDialog extends StatelessWidget {
  final Map<String, dynamic> address;

  const MapDialog({super.key, required this.address});

  Future<void> _testMapsLaunch(BuildContext context) async {
    try {
      print('🧪 Debug: Testing simple URL launch...');
      
      // Test with a simple Google Maps URL
      final testUrl = 'https://www.google.com/maps';
      final uri = Uri.parse(testUrl);
      
      print('🧪 Debug: Testing URL: $testUrl');
      print('🧪 Debug: Can launch: ${await canLaunchUrl(uri)}');
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('✅ Debug: Successfully launched test URL');
      } else {
        print('❌ Debug: Cannot launch test URL');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot launch any URLs. Check device settings.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Debug: Test error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openGoogleMaps(BuildContext context) async {
    try {
      // Create the address string
      final addressString = '${address['street']}, ${address['city']}, ${address['state']} ${address['zipCode']}';
      
      // URL encode the address
      final encodedAddress = Uri.encodeComponent(addressString);
      
      print('🔍 Debug: Trying to open maps for address: $addressString');
      print('🔍 Debug: Encoded address: $encodedAddress');
      
      // Try multiple URL schemes in order of preference
      final List<Map<String, String>> urlsToTry = [
        {
          'name': 'Google Maps Web',
          'url': 'https://www.google.com/maps/search/?api=1&query=$encodedAddress'
        },
        {
          'name': 'Google Maps Alternative',
          'url': 'https://maps.google.com/maps?q=$encodedAddress'
        },
        {
          'name': 'Geo URL',
          'url': 'geo:0,0?q=$encodedAddress'
        },
        {
          'name': 'Maps URL',
          'url': 'maps:0,0?q=$encodedAddress'
        },
        {
          'name': 'Google Maps App',
          'url': 'comgooglemaps://?q=$encodedAddress'
        },
        {
          'name': 'Apple Maps',
          'url': 'http://maps.apple.com/?q=$encodedAddress'
        },
      ];
      
      bool launched = false;
      String lastError = '';
      
      for (Map<String, String> urlInfo in urlsToTry) {
        try {
          final uri = Uri.parse(urlInfo['url']!);
          print('🔍 Debug: Trying ${urlInfo['name']}: ${urlInfo['url']}');
          
          if (await canLaunchUrl(uri)) {
            print('✅ Debug: Can launch ${urlInfo['name']}');
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            launched = true;
            print('✅ Debug: Successfully launched ${urlInfo['name']}');
            break;
          } else {
            print('❌ Debug: Cannot launch ${urlInfo['name']}');
          }
        } catch (e) {
          print('❌ Debug: Error with ${urlInfo['name']}: $e');
          lastError = e.toString();
          continue;
        }
      }
      
      if (!launched) {
        print('❌ Debug: Failed to launch any maps app. Last error: $lastError');
        // Show error message with more details
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open maps app. Last error: $lastError'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Copy Address',
                onPressed: () {
                  // Copy address to clipboard
                  // You can add clipboard functionality here if needed
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Debug: General error: $e');
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening maps: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Location'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: Column(
          children: [
            Text(
              '${address['street']}, ${address['city']}, ${address['state']} ${address['zipCode']}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border.all(color: Colors.blue[200]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map,
                    size: 48,
                    color: Colors.blue[600],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Open in Google Maps',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap the button below to open the location in your default maps app',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () => _openGoogleMaps(context),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open Maps'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[700],
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _testMapsLaunch(context),
          icon: const Icon(Icons.bug_report),
          label: const Text('Test Maps'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange[700],
          ),
        ),
      ],
    );
  }
}
