import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../services/job_service.dart';
import '../services/location_service.dart';
import '../services/camera_service.dart';
import '../services/location_validation_service.dart';

class TodaysJobsScreen extends StatefulWidget {
  const TodaysJobsScreen({super.key});

  @override
  State<TodaysJobsScreen> createState() => _TodaysJobsScreenState();
}

class _TodaysJobsScreenState extends State<TodaysJobsScreen> {
  final JobService _jobService = JobService();
  final LocationService _locationService = LocationService();
  final CameraService _cameraService = CameraService();
  List<dynamic> _jobs = [];
  Map<String, dynamic>? _jobCounts;
  bool _isLoading = true;
  String _selectedFilter = 'all';
  final Map<String, bool> _trackingJobs = {}; // Track which jobs are being tracked

  @override
  void initState() {
    super.initState();
    _loadTodaysJobs();
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
        _loadTodaysJobs();
        _startAutoRefresh(); // Schedule next refresh
      }
    });
  }

  void _stopAutoRefresh() {
    // This will be called when the widget is disposed
  }

  Future<void> _loadTodaysJobs() async {
    setState(() => _isLoading = true);
    
    // Get current location for geographical sorting
    Position? currentPosition;
    try {
      bool hasPermission = await _locationService.requestLocationPermission();
      if (hasPermission) {
        currentPosition = await _locationService.getCurrentLocation();
      }
    } catch (e) {
      print('Error getting location: $e');
    }
    
    // Use geographical sorting if location is available
    final result = currentPosition != null 
        ? await _jobService.getTodaysJobsGeo(
            userLatitude: currentPosition.latitude,
            userLongitude: currentPosition.longitude,
          )
        : await _jobService.getTodaysJobs();

    if (result['success']) {
      // Sort jobs by sequence number (1, 2, 3, etc.) for easy route following
      List<dynamic> jobs = List<dynamic>.from(result['data']['jobs'] ?? []);
      if (jobs.isNotEmpty) {
        jobs.sort((a, b) {
          // Sort by sequenceNumber first (if available)
          final seqA = a['sequenceNumber'];
          final seqB = b['sequenceNumber'];
          
          if (seqA != null && seqB != null) {
            return (seqA as num).compareTo(seqB as num);
          } else if (seqA != null) {
            return -1; // Jobs with sequence numbers come first
          } else if (seqB != null) {
            return 1;
          }
          
          // If no sequence numbers, fall back to distance-based sorting
          double distA = 0.0;
          double distB = 0.0;
          if (a['distanceFromUser'] is num && b['distanceFromUser'] is num) {
            distA = (a['distanceFromUser'] as num).toDouble();
            distB = (b['distanceFromUser'] as num).toDouble();
          } else if (currentPosition != null) {
            final aLat = (a['address']?['latitude'] ?? 0.0) as num;
            final aLng = (a['address']?['longitude'] ?? 0.0) as num;
            final bLat = (b['address']?['latitude'] ?? 0.0) as num;
            final bLng = (b['address']?['longitude'] ?? 0.0) as num;
            if (aLat != 0.0 && aLng != 0.0) {
              distA = Geolocator.distanceBetween(
                currentPosition.latitude,
                currentPosition.longitude,
                aLat.toDouble(),
                aLng.toDouble(),
              );
            }
            if (bLat != 0.0 && bLng != 0.0) {
              distB = Geolocator.distanceBetween(
                currentPosition.latitude,
                currentPosition.longitude,
                bLat.toDouble(),
                bLng.toDouble(),
              );
            }
          }
          return distA.compareTo(distB);
        });
      }

      setState(() {
        _jobs = jobs;
        _jobCounts = result['data']['counts'] ?? {};
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
      _loadTodaysJobs();
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
      case 'electricity': return '⚡';
      case 'gas': return '🔥';
      case 'water': return '💧';
      default: return '📋';
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

  String _getCurrentDate() {
    final now = DateTime.now();
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 
                   'July', 'August', 'September', 'October', 'November', 'December'];
    
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Today\'s Jobs'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTodaysJobs,
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with date and counts
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Text(
                  _getCurrentDate(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildCountCard('Total', _jobs.length, Colors.blue),
                    _buildCountCard('Pending', _jobCounts?['pending'] ?? 0, Colors.orange),
                    _buildCountCard('In Progress', _jobCounts?['inProgress'] ?? 0, Colors.purple),
                    _buildCountCard('Completed', _jobCounts?['completed'] ?? 0, Colors.green),
                  ],
                ),
              ],
            ),
          ),
          
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
                        onRefresh: _loadTodaysJobs,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.work_outline, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No jobs for today',
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
                        onRefresh: _loadTodaysJobs,
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

  Widget _buildCountCard(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
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

  /// Check if a job can be accessed (must be next in sequence or already started/completed)
  bool _canAccessJob(Map<String, dynamic> job) {
    final status = job['status'];
    final sequenceNumber = job['sequenceNumber'];
    
    // If job is already completed or in progress, allow access
    if (status == 'completed' || status == 'in_progress') {
      return true;
    }
    
    // If no sequence number, allow access (backward compatibility)
    if (sequenceNumber == null) {
      return true;
    }
    
    // Find the next available job in sequence
    final nextJob = _getNextAvailableJob();
    
    // If this is the next job in sequence, allow access
    if (nextJob != null && nextJob['_id'] == job['_id']) {
      return true;
    }
    
    // If there's no next job, check if ALL jobs are completed
    // Only then allow access to any remaining pending job
    if (nextJob == null) {
      // Check if there are any pending or in_progress jobs with sequence numbers
      final hasPendingJobs = _jobs.any((j) {
        final s = j['status'];
        final seq = j['sequenceNumber'];
        return (s == 'pending' || s == 'in_progress') && seq != null;
      });
      
      // If no pending jobs exist, all are completed - allow access
      // Otherwise, there are pending jobs but none are next (shouldn't happen, but safety check)
      return !hasPendingJobs;
    }
    
    // Otherwise, this job is not the next in sequence
    return false;
  }
  
  /// Get the next available job in sequence (lowest sequence number that is pending or in_progress)
  Map<String, dynamic>? _getNextAvailableJob() {
    // Filter jobs that are pending or in_progress and have sequence numbers
    final availableJobs = _jobs.where((job) {
      final status = job['status'];
      final sequenceNumber = job['sequenceNumber'];
      return (status == 'pending' || status == 'in_progress') && sequenceNumber != null;
    }).toList();
    
    if (availableJobs.isEmpty) {
      return null;
    }
    
    // Sort by sequence number and return the first one
    availableJobs.sort((a, b) {
      final seqA = a['sequenceNumber'] ?? 999999;
      final seqB = b['sequenceNumber'] ?? 999999;
      return seqA.compareTo(seqB);
    });
    
    return availableJobs.first;
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final address = job['address'];
    final assignedTo = job['assignedTo'];
    final status = job['status'];
    final priority = job['priority'];
    final jobType = job['jobType'];
    final scheduledDate = DateTime.parse(job['scheduledDate']);
    final canAccess = _canAccessJob(job);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: canAccess ? null : Colors.grey[100], // Gray out if not accessible
      child: Opacity(
        opacity: canAccess ? 1.0 : 0.6, // Reduce opacity if not accessible
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Sequence number badge
                  if (job['sequenceNumber'] != null) ...[
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: canAccess ? Colors.blue[700] : Colors.grey[400],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Stack(
                          children: [
                            Text(
                              '${job['sequenceNumber']}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (!canAccess && status == 'pending')
                              const Positioned(
                                right: 0,
                                top: 0,
                                child: Icon(
                                  Icons.lock,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
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
                  'Scheduled: ${scheduledDate.hour.toString().padLeft(2, '0')}:${scheduledDate.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                if (job['distanceFromUser'] != null) ...[
                  const SizedBox(width: 16),
                  const FaIcon(FontAwesomeIcons.locationDot, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    '${job['distanceFromUser'].toStringAsFixed(1)} km',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
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
                      onPressed: canAccess 
                          ? () => _startJobWithLocation(job)
                          : () {
                              // Show message explaining why job cannot be started
                              final nextJob = _getNextAvailableJob();
                              final nextSeq = nextJob?['sequenceNumber'];
                              final currentSeq = job['sequenceNumber'];
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    nextSeq != null && currentSeq != null
                                        ? 'Please complete job #$nextSeq first before starting job #$currentSeq'
                                        : 'Please complete the previous job in sequence first',
                                  ),
                                  backgroundColor: Colors.orange,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            },
                      icon: const FaIcon(FontAwesomeIcons.play, size: 16),
                      label: const Text('Start Work'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canAccess ? Colors.blue[700] : Colors.grey[400],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
                if (status == 'in_progress') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: canAccess
                          ? () => _navigateToMeterReading(job)
                          : () {
                              // Show message explaining why job cannot be accessed
                              final nextJob = _getNextAvailableJob();
                              final nextSeq = nextJob?['sequenceNumber'];
                              final currentSeq = job['sequenceNumber'];
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    nextSeq != null && currentSeq != null
                                        ? 'Please complete job #$nextSeq first before continuing job #$currentSeq'
                                        : 'Please complete the previous job in sequence first',
                                  ),
                                  backgroundColor: Colors.orange,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            },
                      icon: const FaIcon(FontAwesomeIcons.clipboardCheck, size: 16),
                      label: const Text('Take Reading'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canAccess ? Colors.orange[700] : Colors.grey[400],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (!canAccess && status == 'pending' && job['sequenceNumber'] != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Complete previous jobs in sequence first',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[800],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
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
            _loadTodaysJobs();
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

  Future<void> _startJobWithLocation(Map<String, dynamic> job) async {
    try {
      // Request location permission
      bool hasPermission = await _locationService.requestLocationPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required to start work'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get current location
      Position? currentPosition = await _locationService.getCurrentLocation();
      if (currentPosition == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to get current location'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Start job with location tracking
      final result = await _locationService.startJob(job['_id'], currentPosition);
      if (result['success']) {
        setState(() {
          _trackingJobs[job['_id']] = true;
        });
        _loadTodaysJobs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Job started! Opening map for navigation...'),
              backgroundColor: Colors.green,
            ),
          );
          // Automatically open map for navigation
          _showMapDialog(job['address']);
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
    } catch (e) {
      print('Error starting job: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error starting job'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _navigateToMeterReading(Map<String, dynamic> job) async {
    try {
      // Continuously check location with multiple attempts for accuracy
      Position? currentPosition;
      int attempts = 0;
      const maxAttempts = 3;
      
      while (attempts < maxAttempts) {
        currentPosition = await _locationService.getCurrentLocation();
        if (currentPosition != null) break;
        attempts++;
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      if (currentPosition != null) {
        // Try multiple sources for job coordinates
        final jobCoords = await LocationValidationService.getJobCoordinates(job);
        double destLat = jobCoords?['latitude'] ?? job['address']?['latitude'] ?? job['house']?['latitude'] ?? 0.0;
        double destLng = jobCoords?['longitude'] ?? job['address']?['longitude'] ?? job['house']?['longitude'] ?? 0.0;
        
        if (destLat != 0.0 && destLng != 0.0) {
          double distanceInMeters = Geolocator.distanceBetween(
            currentPosition.latitude,
            currentPosition.longitude,
            destLat,
            destLng,
          );

          if (distanceInMeters > LocationValidationService.REQUIRED_RADIUS_METERS) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('You must be within ${LocationValidationService.REQUIRED_RADIUS_METERS.toInt()} meters of the destination to take readings. Current distance: ${distanceInMeters.toStringAsFixed(1)}m. Please ensure GPS is enabled and try again.'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
            return;
          }
        }
      }

      // Navigate to meter reading screen
      final result = await Navigator.pushNamed(
        context,
        '/meter-reading',
        arguments: job,
      );
      
      if (result == true) {
        // Refresh the jobs list if meter reading was successful
        _loadTodaysJobs();
      }
    } catch (e) {
      print('Error navigating to meter reading: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error accessing meter reading'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMeterReadingDialogWithPhotos(Map<String, dynamic> job, Position currentPosition) {
    showDialog(
      context: context,
      builder: (context) => MeterReadingDialogWithPhotos(
        job: job,
        currentPosition: currentPosition,
        locationService: _locationService,
        cameraService: _cameraService,
        onComplete: (readings, photoUrls) async {
          final result = await _locationService.completeJob(
            job['_id'], 
            currentPosition, 
            readings, 
            photoUrls
          );
          if (result['success']) {
            setState(() {
              _trackingJobs.remove(job['_id']);
            });
            _loadTodaysJobs();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Job completed successfully!'),
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
}

class MeterReadingDialogWithPhotos extends StatefulWidget {
  final Map<String, dynamic> job;
  final Position currentPosition;
  final LocationService locationService;
  final CameraService cameraService;
  final Function(Map<String, dynamic>, List<String>) onComplete;

  const MeterReadingDialogWithPhotos({
    super.key,
    required this.job,
    required this.currentPosition,
    required this.locationService,
    required this.cameraService,
    required this.onComplete,
  });

  @override
  State<MeterReadingDialogWithPhotos> createState() => _MeterReadingDialogWithPhotosState();
}

class _MeterReadingDialogWithPhotosState extends State<MeterReadingDialogWithPhotos> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, TextEditingController> _serialControllers = {};
  final Map<String, File?> _photos = {};
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final jobType = widget.job['jobType'] ?? 'all';
    
    if (jobType == 'all' || jobType == 'electricity') {
      _controllers['electric'] = TextEditingController();
      _serialControllers['electric'] = TextEditingController();
    }
    if (jobType == 'all' || jobType == 'gas') {
      _controllers['gas'] = TextEditingController();
      _serialControllers['gas'] = TextEditingController();
    }
    if (jobType == 'all' || jobType == 'water') {
      _controllers['water'] = TextEditingController();
      _serialControllers['water'] = TextEditingController();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Submit Meter Readings'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(height: 8),
                    Text(
                      'Address: ${widget.job['address']['street']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Please enter readings and take photos of each meter with visible serial numbers.',
                      style: TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ..._controllers.entries.map((entry) => Column(
                children: [
                  TextField(
                    controller: entry.value,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '${entry.key.toUpperCase()} Reading',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _serialControllers[entry.key],
                    decoration: InputDecoration(
                      labelText: '${entry.key.toUpperCase()} Serial Number',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _takePhoto(entry.key),
                          icon: const Icon(Icons.camera_alt),
                          label: Text(_photos[entry.key] != null ? 'Retake Photo' : 'Take Photo'),
                        ),
                      ),
                      if (_photos[entry.key] != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _viewPhoto(entry.key),
                            icon: const Icon(Icons.visibility),
                            label: const Text('View'),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              )),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isUploading ? null : _submitReadings,
          child: _isUploading 
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Submit & Complete'),
        ),
      ],
    );
  }

  Future<void> _takePhoto(String meterType) async {
    try {
      File? photo = await widget.cameraService.takePhoto();
      if (photo != null) {
        setState(() {
          _photos[meterType] = photo;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewPhoto(String meterType) {
    if (_photos[meterType] != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${meterType.toUpperCase()} Meter Photo'),
          content: Image.file(_photos[meterType]!),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _submitReadings() async {
    // Validate that all required fields are filled
    bool hasReadings = false;
    bool hasPhotos = false;
    
    for (final entry in _controllers.entries) {
      if (entry.value.text.isNotEmpty) {
        hasReadings = true;
        if (_photos[entry.key] != null) {
          hasPhotos = true;
        }
      }
    }

    if (!hasReadings) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least one meter reading'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!hasPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please take photos of all meters with visible serial numbers'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Upload photos
      List<String> photoUrls = [];
      for (String meterType in _photos.keys) {
        if (_photos[meterType] != null) {
          String? url = await widget.cameraService.uploadPhoto(
            _photos[meterType]!,
            widget.job['_id'],
            meterType,
          );
          if (url != null) {
            photoUrls.add(url);
          }
        }
      }

      // Prepare readings
      Map<String, dynamic> readings = {};
      for (final entry in _controllers.entries) {
        if (entry.value.text.isNotEmpty) {
          readings[entry.key] = double.tryParse(entry.value.text) ?? 0;
        }
      }

      widget.onComplete(readings, photoUrls);
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting readings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
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
      ],
    );
  }
}
