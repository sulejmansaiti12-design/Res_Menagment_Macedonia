import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/app_theme.dart';
import '../../services/api_client.dart';
import 'customer_menu_screen.dart';

class CustomerLanguageScreen extends StatefulWidget {
  final Map<String, dynamic> tableData;
  final ApiClient api;

  const CustomerLanguageScreen({super.key, required this.tableData, required this.api});

  @override
  State<CustomerLanguageScreen> createState() => _CustomerLanguageScreenState();
}

class _CustomerLanguageScreenState extends State<CustomerLanguageScreen> {
  void _selectLanguage(String langCode) async {
    await context.setLocale(Locale(langCode));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: 600.ms,
          pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
            opacity: animation,
            child: CustomerMenuScreen(tableData: widget.tableData, api: widget.api),
          ),
        ),
      );
    }
  }

  Widget _buildLangButton(String code, String name, String subtitle, IconData icon) {
    return InkWell(
      onTap: () => _selectLanguage(code),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primaryLight, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tableName = widget.tableData['table']?['name'] as String? ?? 'Table';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.surfaceDark, AppTheme.background],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Animated Icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accent.withValues(alpha: 0.1),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accent.withValues(alpha: 0.2),
                              blurRadius: 30,
                              spreadRadius: 5,
                            )
                          ],
                        ),
                        child: const Icon(Icons.language_rounded, size: 64, color: AppTheme.accent),
                      ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack).fade(),
                    ),
                    const SizedBox(height: 40),
                    
                    // Welcome Texts
                    Text(
                      'Welcome to $tableName',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ).animate().fade(delay: 200.ms, duration: 500.ms).slideY(begin: 0.2),
                    
                    const SizedBox(height: 12),
                    
                    const Text(
                      'Please choose your preferred language to view our menu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ).animate().fade(delay: 400.ms, duration: 500.ms).slideY(begin: 0.2),
                    
                    const SizedBox(height: 48),
                    
                    // Language Buttons Staggered
                    _buildLangButton('en', 'English', 'View menu in English', Icons.g_translate)
                        .animate(delay: 600.ms)
                        .fade(duration: 400.ms)
                        .slideX(begin: 0.1),
                        
                    _buildLangButton('mk', 'Македонски', 'Гледајте го менито на Македонски', Icons.g_translate)
                        .animate(delay: 700.ms)
                        .fade(duration: 400.ms)
                        .slideX(begin: 0.1),
                        
                    _buildLangButton('sq', 'Shqip', 'Shikoni menynë në Shqip', Icons.g_translate)
                        .animate(delay: 800.ms)
                        .fade(duration: 400.ms)
                        .slideX(begin: 0.1),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
