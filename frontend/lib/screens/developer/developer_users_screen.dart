import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/api_client.dart';

class DeveloperUsersScreen extends StatefulWidget {
  final ApiClient apiClient;
  const DeveloperUsersScreen({super.key, required this.apiClient});

  @override
  State<DeveloperUsersScreen> createState() => _DeveloperUsersScreenState();
}

class _DeveloperUsersScreenState extends State<DeveloperUsersScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  bool _loading = true;
  List<Map<String, dynamic>> _admins = [];
  List<Map<String, dynamic>> _owners = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final a = await widget.apiClient.get('/developer/users?role=admin');
      final o = await widget.apiClient.get('/developer/users?role=owner');
      setState(() {
        _admins = List<Map<String, dynamic>>.from((a['data']['users'] as List).map((u) => Map<String, dynamic>.from(u as Map)));
        _owners = List<Map<String, dynamic>>.from((o['data']['users'] as List).map((u) => Map<String, dynamic>.from(u as Map)));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _currentList() => _tab.index == 0 ? _admins : _owners;
  String _currentRole() => _tab.index == 0 ? 'admin' : 'owner';

  Future<void> _addUser() async {
    final nameC = TextEditingController();
    final usernameC = TextEditingController();
    final passwordC = TextEditingController();
    final role = _currentRole();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add ${role.toUpperCase()}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameC, decoration: const InputDecoration(hintText: 'Full Name')),
            const SizedBox(height: 12),
            TextField(controller: usernameC, decoration: const InputDecoration(hintText: 'Username')),
            const SizedBox(height: 12),
            TextField(controller: passwordC, decoration: const InputDecoration(hintText: 'Password'), obscureText: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.apiClient.post('/developer/users', body: {
                  'name': nameC.text.trim(),
                  'username': usernameC.text.trim(),
                  'password': passwordC.text,
                  'role': role,
                });
                _loadAll();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Create failed: $e'), backgroundColor: AppTheme.error),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _editUser(Map<String, dynamic> u) async {
    final nameC = TextEditingController(text: (u['name'] ?? '').toString());
    final usernameC = TextEditingController(text: (u['username'] ?? '').toString());
    final passwordC = TextEditingController();
    bool isActive = u['isActive'] == true;
    final role = _currentRole();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: Text('Edit ${role.toUpperCase()}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC, decoration: const InputDecoration(hintText: 'Full Name')),
              const SizedBox(height: 12),
              TextField(controller: usernameC, decoration: const InputDecoration(hintText: 'Username')),
              const SizedBox(height: 12),
              TextField(controller: passwordC, decoration: const InputDecoration(hintText: 'New Password (optional)'), obscureText: true),
              const SizedBox(height: 12),
              SwitchListTile(
                value: isActive,
                onChanged: (v) => ss(() => isActive = v),
                title: const Text('Active'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final body = <String, dynamic>{
                    'name': nameC.text.trim(),
                    'username': usernameC.text.trim(),
                    'isActive': isActive,
                    'role': role,
                  };
                  if (passwordC.text.isNotEmpty) body['password'] = passwordC.text;
                  await widget.apiClient.put('/developer/users/${u['id']}', body: body);
                  _loadAll();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Update failed: $e'), backgroundColor: AppTheme.error),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deactivateUser(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate user'),
        content: const Text('Deactivate this account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.apiClient.delete('/developer/users/$id');
      _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deactivate failed: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admins & Owners'),
        bottom: TabBar(
          controller: _tab,
          onTap: (_) => setState(() {}),
          tabs: const [
            Tab(text: 'Admins'),
            Tab(text: 'Owners'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _currentList().length,
                itemBuilder: (ctx, i) {
                  final u = _currentList()[i];
                  final isActive = u['isActive'] == true;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isActive ? AppTheme.success : AppTheme.textSecondary,
                        child: Text((u['name'] as String? ?? 'U')[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                      ),
                      title: Text(u['name'] as String? ?? ''),
                      subtitle: Text('${u['username'] ?? ''} • ${isActive ? 'Active' : 'Inactive'}',
                          style: const TextStyle(color: AppTheme.textSecondary)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: AppTheme.info),
                            onPressed: () => _editUser(u),
                          ),
                          IconButton(
                            icon: const Icon(Icons.person_off, color: AppTheme.error),
                            onPressed: () => _deactivateUser(u['id'] as String),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addUser,
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

