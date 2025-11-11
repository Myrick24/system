import 'package:flutter/material.dart';
import '../tools/cooperative_chat_database_setup.dart';

/// Test screen to setup and verify cooperative chat database
/// Use this to create the database structure and test it
class TestCooperativeChatScreen extends StatefulWidget {
  const TestCooperativeChatScreen({Key? key}) : super(key: key);

  @override
  State<TestCooperativeChatScreen> createState() => _TestCooperativeChatScreenState();
}

class _TestCooperativeChatScreenState extends State<TestCooperativeChatScreen> {
  bool _isLoading = false;
  String _output = 'Ready to setup cooperative chat database';

  Future<void> _runTask(Future<void> Function() task, String taskName) async {
    setState(() {
      _isLoading = true;
      _output = 'Running: $taskName...\n';
    });

    try {
      await task();
      setState(() {
        _isLoading = false;
        _output += '\n✅ Completed!';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _output += '\n❌ Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cooperative Chat Setup'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Database Setup Tool',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Use these buttons to create and test the cooperative chat database structure.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Buttons
            _buildActionButton(
              icon: Icons.add_circle,
              label: 'Create Test Database',
              description: 'Creates sample chats and messages',
              color: Colors.blue,
              onPressed: () => _runTask(
                CooperativeChatDatabaseSetup.setupTestDatabase,
                'Creating test database',
              ),
            ),

            const SizedBox(height: 12),

            _buildActionButton(
              icon: Icons.verified,
              label: 'Verify Structure',
              description: 'Check if database is setup correctly',
              color: Colors.green,
              onPressed: () => _runTask(
                CooperativeChatDatabaseSetup.verifyDatabaseStructure,
                'Verifying database structure',
              ),
            ),

            const SizedBox(height: 12),

            _buildActionButton(
              icon: Icons.list,
              label: 'List My Chats',
              description: 'Show all chats for current user',
              color: Colors.orange,
              onPressed: () => _runTask(
                CooperativeChatDatabaseSetup.listUserChats,
                'Listing chats',
              ),
            ),

            const SizedBox(height: 12),

            _buildActionButton(
              icon: Icons.delete_forever,
              label: 'Delete All Chats',
              description: 'Remove all chats (for cleanup)',
              color: Colors.red,
              onPressed: () => _showDeleteConfirmation(),
            ),

            const SizedBox(height: 24),

            // Output Console
            Card(
              child: Container(
                padding: const EdgeInsets.all(16),
                constraints: const BoxConstraints(minHeight: 200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.terminal, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Console Output',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(color: Colors.green),
                        ),
                      )
                    else
                      Text(
                        _output,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Database Structure Info
            Card(
              color: Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.storage, color: Colors.grey.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Database Structure',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildStructureItem('Collection', 'cooperative_chats'),
                    _buildStructureItem('  └─ Document ID', 'auto-generated'),
                    _buildStructureItem('      ├─ cooperativeId', 'string'),
                    _buildStructureItem('      ├─ userId', 'string'),
                    _buildStructureItem('      ├─ chatType', 'string'),
                    _buildStructureItem('      ├─ lastMessage', 'string'),
                    _buildStructureItem('      ├─ unreadUserCount', 'number'),
                    _buildStructureItem('      ├─ unreadCooperativeCount', 'number'),
                    _buildStructureItem('      └─ Sub-collection', 'messages'),
                    _buildStructureItem('          ├─ text', 'string'),
                    _buildStructureItem('          ├─ senderId', 'string'),
                    _buildStructureItem('          ├─ timestamp', 'timestamp'),
                    _buildStructureItem('          └─ isRead', 'boolean'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: _isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStructureItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Chats?'),
        content: const Text(
          'This will permanently delete all cooperative chats and messages. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _runTask(
                CooperativeChatDatabaseSetup.deleteAllChats,
                'Deleting all chats',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }
}
