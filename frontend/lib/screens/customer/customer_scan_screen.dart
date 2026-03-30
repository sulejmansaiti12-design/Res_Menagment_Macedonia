import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/app_config.dart';
import '../../config/app_theme.dart';
import '../../services/api_client.dart';
import 'customer_menu_screen.dart';
import 'customer_language_screen.dart';

class CustomerScanScreen extends StatefulWidget {
  const CustomerScanScreen({super.key});

  @override
  State<CustomerScanScreen> createState() => _CustomerScanScreenState();
}

class _CustomerScanScreenState extends State<CustomerScanScreen> {
  final _tokenController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _joinTable(String qrToken) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ApiClient();
      final res = await api.get('/customer/table/$qrToken');
      final data = res['data'] as Map<String, dynamic>;

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerLanguageScreen(
              tableData: data,
              api: api,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.primaryDark, AppTheme.background],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(color: AppTheme.primaryLight.withValues(alpha: 0.2), blurRadius: 40, spreadRadius: 10),
                      ],
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded, size: 56, color: AppTheme.primaryLight),
                  ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scaleXY(end: 1.05, duration: 1200.ms),
                  const SizedBox(height: 32),
                  Text(
                    'Scan QR Code',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Scan the QR code on your table or enter the code manually',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 32),

                  // Manual token entry
                  Container(
                    width: 350,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _tokenController,
                          decoration: const InputDecoration(
                            hintText: 'Enter table code',
                            prefixIcon: Icon(Icons.qr_code, color: AppTheme.textSecondary),
                          ),
                          style: const TextStyle(color: AppTheme.textPrimary),
                          onSubmitted: (v) => _joinTable(v.trim()),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () => _joinTable(_tokenController.text.trim()),
                            child: _isLoading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Join Table'),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: AppTheme.textSecondary),
                    label: const Text('Back to Login', style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                ],
              ).animate().fade(duration: 600.ms).slideY(begin: 0.1),
            ),
          ),
        ),
      ),
    );
  }
}
