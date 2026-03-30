import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import 'developer_db_settings_screen.dart';
import 'developer_fiscal_screen.dart';
import 'developer_logs_screen.dart';
import 'developer_users_screen.dart';

class DeveloperHomeScreen extends StatelessWidget {
  final ApiClient apiClient;
  const DeveloperHomeScreen({super.key, required this.apiClient});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Console', style: TextStyle(fontWeight: FontWeight.w800)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.error),
            onPressed: () => auth.logout(),
            tooltip: 'Logout',
          ),
          const SizedBox(width: 8),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.background, AppTheme.surface],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            children: [
              _HeaderCard(name: auth.userName),
              const SizedBox(height: 32),
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  'SYSTEM CONFIGURATION',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _NavCard(
                icon: Icons.storage_rounded,
                title: 'Database Settings',
                subtitle: 'Edit backend DB connection (.env) and test connection',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DeveloperDbSettingsScreen(apiClient: apiClient)),
                ),
              ),
              _NavCard(
                icon: Icons.admin_panel_settings_rounded,
                title: 'Admins & Owners',
                subtitle: 'Add/edit/deactivate admin and owner accounts',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DeveloperUsersScreen(apiClient: apiClient)),
                ),
              ),
              _NavCard(
                icon: Icons.receipt_long_rounded,
                title: 'Fiscal Integration',
                subtitle: 'Configure fiscal provider settings and test receipt (MKD)',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DeveloperFiscalScreen(apiClient: apiClient)),
                ),
              ),
              _NavCard(
                icon: Icons.monitor_heart_rounded,
                title: 'Real-time Logs',
                subtitle: 'Watch server output and error logs (auto-refresh)',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DeveloperLogsScreen(apiClient: apiClient)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String name;
  const _HeaderCard({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: const Icon(Icons.code_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Developer Access',
                  style: TextStyle(
                    color: AppTheme.primaryLight,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name.isEmpty ? 'Developer' : name,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 4),
                const Text('Full System Control', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_NavCard> createState() => _NavCardState();
}

class _NavCardState extends State<_NavCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _isHovered ? AppTheme.surfaceLight : AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isHovered ? AppTheme.primary.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
              boxShadow: _isHovered
                  ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 6))]
                  : [],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Icon(widget.icon, color: AppTheme.accent, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(height: 4),
                      Text(widget.subtitle, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textSecondary.withValues(alpha: 0.5), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

