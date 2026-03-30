import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/api_client.dart';

class DeveloperFiscalScreen extends StatefulWidget {
  final ApiClient apiClient;
  const DeveloperFiscalScreen({super.key, required this.apiClient});

  @override
  State<DeveloperFiscalScreen> createState() => _DeveloperFiscalScreenState();
}

class _DeveloperFiscalScreenState extends State<DeveloperFiscalScreen> {
  bool _loading = true;
  bool _saving = false;

  bool _enabled = false;
  String _provider = 'stub';
  List<Map<String, dynamic>> _providers = const [
    {'id': 'stub', 'label': 'Stub (demo)'},
    {'id': 'http', 'label': 'HTTP Middleware'},
    {'id': 'file', 'label': 'XML File Drop'},
  ];
  final _apiBaseUrlC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiBaseUrlC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      try {
        final pRes = await widget.apiClient.get('/developer/fiscal/providers');
        final list = List<Map<String, dynamic>>.from(
          (pRes['data']['providers'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        if (list.isNotEmpty) _providers = list;
      } catch (_) {}

      final res = await widget.apiClient.get('/developer/fiscal/settings');
      final fiscal = res['data']['fiscal'] as Map<String, dynamic>;
      setState(() {
        _enabled = fiscal['enabled'] == true;
        _provider = (fiscal['provider'] ?? 'stub').toString();
        _apiBaseUrlC.text = (fiscal['apiBaseUrl'] ?? '').toString();
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load: $e'), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.apiClient.put('/developer/fiscal/settings', body: {
        'enabled': _enabled,
        'country': 'MK',
        'provider': _provider,
        'apiBaseUrl': _apiBaseUrlC.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Row(children: [Icon(Icons.check_circle_rounded, color: Colors.white), SizedBox(width: 12), Text('Fiscal settings saved', style: TextStyle(fontWeight: FontWeight.bold))]), backgroundColor: AppTheme.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        );
      }
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e'), backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    setState(() => _saving = true);
    try {
      final res = await widget.apiClient.post('/developer/fiscal/test');
      final receipt = res['data']['receipt'] as Map<String, dynamic>;
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            title: const Row(
              children: [
                Icon(Icons.receipt_long_rounded, color: AppTheme.success),
                SizedBox(width: 12),
                Text('Test Successful', style: TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('The backend fiscal service responded:', style: TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(12)),
                  child: Text('Receipt #${receipt['fiscalNumber'] ?? 'Unknown'}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primaryLight, letterSpacing: 1.2)),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.all(24),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), style: TextButton.styleFrom(minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white))),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Test failed: $e'), backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('North Macedonia Fiscal API', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [AppTheme.background, AppTheme.surface], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.3)),
                        boxShadow: [BoxShadow(color: AppTheme.primaryLight.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: AppTheme.primaryLight.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
                                child: const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryLight, size: 28),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('HARDWARE BRIDGE', style: TextStyle(color: AppTheme.primaryLight, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                                    SizedBox(height: 4),
                                    Text('Integration Setup', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _enabled,
                                onChanged: (v) => setState(() => _enabled = v),
                                activeColor: AppTheme.primaryLight,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Text('Configure how the Node.js backend communicates with the local MK certified fiscal printer (Accent, David, Synergy).', style: TextStyle(color: AppTheme.textSecondary, height: 1.4, fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CONNECTION TYPE', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _provider,
                            dropdownColor: AppTheme.surfaceLight,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppTheme.surfaceLight,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 16),
                            items: _providers.map((p) => DropdownMenuItem<String>(value: p['id'].toString(), child: Text(p['label'].toString()))).toList(),
                            onChanged: _enabled ? (v) { if (v != null) setState(() => _provider = v); } : null,
                          ),
                          
                          if (_provider != 'stub') ...[
                            const SizedBox(height: 24),
                            Text(_provider == 'file' ? 'XML DROP FOLDER PATH' : 'MIDDLEWARE API URL', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _apiBaseUrlC,
                              enabled: _enabled,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                hintText: _provider == 'file' ? 'e.g., C:\\Fiscal\\Out\\' : 'e.g., http://localhost:8181',
                                hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                                filled: true,
                                fillColor: AppTheme.surfaceLight,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _provider == 'file' 
                                ? 'The backend will generate MK format XML files and drop them into this folder.'
                                : 'The backend will POST JSON receipts to this local middleware address.',
                              style: const TextStyle(color: AppTheme.info, fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _test,
                            icon: const Icon(Icons.speed_rounded),
                            label: const Text('Test Connection'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textPrimary,
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save_rounded),
                            label: const Text('Save Setup', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
