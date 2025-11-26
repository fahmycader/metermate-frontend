import 'package:flutter/material.dart';
import '../services/messages_service.dart';
import '../services/settings_service.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final MessagesService _messagesService = MessagesService();
  bool _isLoading = true;
  List<dynamic> _messages = [];
  String _filter = 'all'; // 'all', 'unread', 'starred'
  double _fontSize = 14.0;

  @override
  void initState() {
    super.initState();
    _loadFontSize();
    _load();
  }

  Future<void> _loadFontSize() async {
    final fontSize = await SettingsService.getFontSize();
    setState(() {
      _fontSize = fontSize;
    });
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await _messagesService.getMyMessages();
    if (result['success']) {
      setState(() {
        _messages = result['data'] ?? [];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to fetch messages')),
        );
      }
    }
  }

  Future<void> _deleteMessage(String id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await _messagesService.deleteMessage(id);
      if (result['success']) {
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to delete message'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleStar(String id) async {
    final result = await _messagesService.toggleStar(id);
    if (result['success']) {
      _load();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to star message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pokeAdmin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Poke Admin'),
        content: const Text('Send a notification to admin? They will be notified that you need attention.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Poke'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await _messagesService.pokeAdmin();
      if (result['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Admin has been notified!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to notify admin'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _markAsRead(String id) async {
    await _messagesService.markRead(id);
    _load();
  }

  List<dynamic> get _filteredMessages {
    List<dynamic> filtered = List.from(_messages);
    
    if (_filter == 'unread') {
      filtered = filtered.where((m) => m['read'] != true).toList();
    } else if (_filter == 'starred') {
      filtered = filtered.where((m) => m['starred'] == true).toList();
    }
    
    // Sort: starred first, then unread, then by date
    filtered.sort((a, b) {
      if (a['starred'] == true && b['starred'] != true) return -1;
      if (a['starred'] != true && b['starred'] == true) return 1;
      if (a['read'] != true && b['read'] == true) return -1;
      if (a['read'] == true && b['read'] != true) return 1;
      final dateA = DateTime.parse(a['createdAt'] ?? DateTime.now().toIso8601String());
      final dateB = DateTime.parse(b['createdAt'] ?? DateTime.now().toIso8601String());
      return dateB.compareTo(dateA);
    });
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active),
            tooltip: 'Poke Admin',
            onPressed: _pokeAdmin,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildFilterChip('all', 'All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('unread', 'Unread'),
                  const SizedBox(width: 8),
                  _buildFilterChip('starred', 'Starred'),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          
          // Messages list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredMessages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No messages',
                                style: TextStyle(
                                  fontSize: _fontSize + 2,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredMessages.length,
                          itemBuilder: (context, index) {
                            final m = _filteredMessages[index];
                            final read = m['read'] == true;
                            final starred = m['starred'] == true;
                            return _buildMessageCard(m, read, starred);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filter = value;
        });
      },
      selectedColor: Colors.blue[100],
      checkmarkColor: Colors.blue[700],
    );
  }

  Widget _buildMessageCard(Map<String, dynamic> message, bool read, bool starred) {
    final title = message['title'] ?? '';
    final body = message['body'] ?? '';
    final createdAt = message['createdAt'] != null
        ? DateTime.parse(message['createdAt'])
        : DateTime.now();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: starred ? 4 : 2,
      color: starred ? Colors.amber[50] : null,
      child: InkWell(
        onTap: () => _showMessageDetail(message),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (starred)
                    Icon(Icons.star, color: Colors.amber[700], size: 20)
                  else
                    Icon(Icons.star_border, color: Colors.grey[400], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: _fontSize + 2,
                        fontWeight: read ? FontWeight.normal : FontWeight.bold,
                        color: read ? Colors.grey[700] : Colors.black,
                      ),
                    ),
                  ),
                  if (!read)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: TextStyle(
                  fontSize: _fontSize,
                  color: Colors.grey[700],
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDate(createdAt),
                    style: TextStyle(
                      fontSize: _fontSize - 2,
                      color: Colors.grey[600],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          starred ? Icons.star : Icons.star_border,
                          color: starred ? Colors.amber[700] : Colors.grey,
                        ),
                        onPressed: () => _toggleStar(message['_id']),
                        tooltip: starred ? 'Unstar' : 'Star',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteMessage(message['_id'], title),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageDetail(Map<String, dynamic> message) {
    final read = message['read'] == true;
    if (!read) {
      _markAsRead(message['_id']);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            if (message['starred'] == true)
              Icon(Icons.star, color: Colors.amber[700], size: 20),
            if (message['starred'] == true) const SizedBox(width: 8),
            Expanded(
              child: Text(
                message['title'] ?? '',
                style: TextStyle(fontSize: _fontSize + 2),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message['body'] ?? '',
                style: TextStyle(fontSize: _fontSize),
              ),
              if (message['createdAt'] != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Received: ${_formatDate(DateTime.parse(message['createdAt']))}',
                  style: TextStyle(
                    fontSize: _fontSize - 2,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          IconButton(
            icon: Icon(
              message['starred'] == true ? Icons.star : Icons.star_border,
              color: message['starred'] == true ? Colors.amber[700] : Colors.grey,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _toggleStar(message['_id']);
            },
            tooltip: message['starred'] == true ? 'Unstar' : 'Star',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () {
              Navigator.of(context).pop();
              _deleteMessage(message['_id'], message['title'] ?? '');
            },
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
