import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/auth_service.dart';
import '../services/job_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final JobService _jobService = JobService();
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _todaysJobsData;
  Map<String, dynamic>? _myJobCountData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadTodaysJobs();
    _loadMyJobCount();
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
        _loadMyJobCount();
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

  Future<void> _loadTodaysJobs() async {
    final result = await _jobService.getTodaysJobs();
    setState(() {
      if (result['success']) {
        _todaysJobsData = result['data'];
      }
      _isLoading = false;
    });
  }

  Future<void> _loadMyJobCount() async {
    final result = await _jobService.getMyJobCount();
    setState(() {
      if (result['success']) {
        _myJobCountData = result['data'];
      }
    });
  }

  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _authService.logout();
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 
                   'July', 'August', 'September', 'October', 'November', 'December'];
    
    return '${weekdays[now.weekday - 1]} ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final fullName = _userData?['firstName'] != null && _userData?['lastName'] != null
        ? '${_userData!['firstName']} ${_userData!['lastName']}'
        : _userData?['username'] ?? 'User';
    
    final employeeId = _userData?['employeeId'] ?? 'N/A';
    final jobsCompleted = _userData?['jobsCompleted'] ?? 0;
    final weeklyPerformance = (_userData?['weeklyPerformance'] ?? 0).toDouble();
    
    // Today's jobs data
    final todaysJobCount = _todaysJobsData?['count'] ?? 0;
    final todaysJobCounts = _todaysJobsData?['counts'] ?? {};
    final pendingCount = todaysJobCounts['pending'] ?? 0;
    final inProgressCount = todaysJobCounts['inProgress'] ?? 0;
    final completedCount = todaysJobCounts['completed'] ?? 0;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadTodaysJobs();
            await _loadMyJobCount();
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(fullName, employeeId),
                const SizedBox(height: 24),
                _buildTodaysJobsCards(todaysJobCount, pendingCount, inProgressCount, completedCount),
                const SizedBox(height: 24),
                _buildPerformanceCard(weeklyPerformance),
                const SizedBox(height: 24),
                _buildActionList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String fullName, String employeeId) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const FaIcon(FontAwesomeIcons.database, color: Colors.blue, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome Back!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Employee ID: $employeeId',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                Text(
                  _getCurrentDate(),
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _handleLogout,
            icon: const FaIcon(FontAwesomeIcons.arrowRightFromBracket, color: Colors.red, size: 16),
            label: const Text('Logout', style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  Widget _buildTodaysJobsCards(int todaysJobCount, int pendingCount, int inProgressCount, int completedCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Today's Jobs",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Align(
                      alignment: Alignment.topRight,
                      child: FaIcon(FontAwesomeIcons.listCheck, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$todaysJobCount',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const Text('Total Jobs', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Align(
                      alignment: Alignment.topRight,
                      child: FaIcon(FontAwesomeIcons.clock, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$pendingCount',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const Text('Pending', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Align(
                      alignment: Alignment.topRight,
                      child: FaIcon(FontAwesomeIcons.spinner, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$inProgressCount',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const Text('In Progress', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Align(
                      alignment: Alignment.topRight,
                      child: FaIcon(FontAwesomeIcons.check, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$completedCount',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const Text('Completed', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPerformanceCard(double weeklyPerformance) {
    return _buildCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              FaIcon(FontAwesomeIcons.chartLine, color: Colors.purple),
              SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Weekly Performance', style: TextStyle(color: Colors.grey)),
                  Text('Completion Rate', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${weeklyPerformance.toStringAsFixed(0)}%', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
              const Text('vs last week', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildActionList() {
    return Column(
      children: [
        _buildActionItem(
            icon: FontAwesomeIcons.calendarDay,
            title: "Today's Jobs",
            subtitle: 'View and manage today\'s assigned jobs',
            iconColor: Colors.blue,
            onTap: () {
              Navigator.of(context).pushNamed('/todays-jobs');
            }),
        const SizedBox(height: 12),
        _buildActionItem(
            icon: FontAwesomeIcons.gears,
            title: 'App Settings',
            subtitle: 'Customize your app preferences',
            iconColor: Colors.grey),
        const SizedBox(height: 12),
        _buildActionItem(
            icon: FontAwesomeIcons.solidComment,
            title: 'Messages',
            subtitle: 'Company updates and notifications',
            iconColor: Colors.green),
        const SizedBox(height: 12),
        _buildActionItem(
            icon: FontAwesomeIcons.solidAddressBook,
            title: 'Contacts',
            subtitle: 'Important contact information',
            iconColor: Colors.orange),
      ],
    );
  }

  Widget _buildActionItem(
      {required IconData icon,
      required String title,
      required String subtitle,
      required Color iconColor,
      VoidCallback? onTap}) {
    return _buildCard(
      child: ListTile(
        leading: FaIcon(icon, color: iconColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
} 