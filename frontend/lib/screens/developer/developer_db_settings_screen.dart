import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/api_client.dart';

class DeveloperDbSettingsScreen extends StatefulWidget {
  final ApiClient apiClient;
  const DeveloperDbSettingsScreen({super.key, required this.apiClient});

  @override
  State<DeveloperDbSettingsScreen> createState() => _DeveloperDbSettingsScreenState();
}

class _DeveloperDbSettingsScreenState extends State<DeveloperDbSettingsScreen> {
  final _hostC = TextEditingController();
  final _portC = TextEditingController();
  final _nameC = TextEditingController();
  final _userC = TextEditingController();
  final _passwordC = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hostC.dispose();
    _portC.dispose();
    _nameC.dispose();
    _userC.dispose();
    _passwordC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await widget.apiClient.get('/developer/db-env');
      final db = res['data']['db'] as Map<String, dynamic>;
      _hostC.text = (db['host'] ?? '').toString();
      _portC.text = (db['port'] ?? '').toString();
      _nameC.text = (db['name'] ?? '').toString();
      _userC.text = (db['user'] ?? '').toString();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _test() async {
    try {
      await widget.apiClient.post('/developer/db-env/test', body: {
        'host': _hostC.text.trim(),
        'port': _portC.text.trim(),
        'name': _nameC.text.trim(),
        'user': _userC.text.trim(),
        'password': _passwordC.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('DB connection OK'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('DB test failed: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final res = await widget.apiClient.put('/developer/db-env', body: {
        'host': _hostC.text.trim(),
        'port': _portC.text.trim(),
        'name': _nameC.text.trim(),
        'user': _userC.text.trim(),
        'password': _passwordC.text,
      });
      final restart = (res['data']?['restartRequired'] == true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(restart ? 'Saved. Restart backend to apply.' : 'Saved.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Database Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.warning.withValues(alpha: 0.25)),
                    ),
                    child: const Text(
                      'This updates backend/.env DB_* values. Restart the backend server after saving.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(controller: _hostC, decoration: const InputDecoration(hintText: 'DB Host (e.g. localhost)')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _portC,
                    decoration: const InputDecoration(hintText: 'DB Port (e.g. 5432)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: _nameC, decoration: const InputDecoration(hintText: 'DB Name')),
                  const SizedBox(height: 12),
                  TextField(controller: _userC, decoration: const InputDecoration(hintText: 'DB User')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordC,
                    decoration: const InputDecoration(hintText: 'DB Password'),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : _test,
                          icon: const Icon(Icons.wifi_tethering),
                          label: const Text('Test'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.save),
                          label: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

