import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../config/app_theme.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';

/// Shared Settings Screen — accessible from every role.
/// Covers: Appearance (Light/Dark/System), Language, Account info, Logout.
/// Admin/Owner/Developer also see Fiscal shortcut.
class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final auth = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;
    final isDark = AppTheme.isDark(context);
    final surface = AppTheme.surfaceColor(context);
    final bg = AppTheme.bg(context);
    final textMuted = AppTheme.textMuted(context);
    final border = AppTheme.borderColor(context);
    final role = auth.userRole;
    final isPrivileged = ['owner', 'admin', 'developer'].contains(role);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18,
            color: AppTheme.primaryColor(context)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [

          // ─── ACCOUNT CARD ────────────────────────────────
          _SectionHeader('ACCOUNT'),
          _CardGroup(
            border: border,
            surface: surface,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _roleGradient(role),
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          auth.userName.isNotEmpty ? auth.userName[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(auth.userName,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _roleColor(role, context).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              role.toUpperCase().replaceAll('_', ' '),
                              style: TextStyle(
                                color: _roleColor(role, context),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ─── APPEARANCE ────────────────────────────────
          _SectionHeader('APPEARANCE'),
          _CardGroup(
            border: border,
            surface: surface,
            children: [
              // Segmented control style theme picker
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Theme', style: TextStyle(color: textMuted, fontSize: 13)),
                    const SizedBox(height: 12),
                    _ThemeSegmentedControl(
                      current: themeProvider.themeMode,
                      onChanged: (m) => themeProvider.setTheme(m),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ─── LANGUAGE ─────────────────────────────────
          _SectionHeader('LANGUAGE'),
          _CardGroup(
            border: border,
            surface: surface,
            children: [
              _LangTile(label: 'English',    locale: const Locale('en'), icon: '🇬🇧'),
              Divider(height: 1, color: border.withValues(alpha: 0.5)),
              _LangTile(label: 'Macedonian / Македонски', locale: const Locale('mk'), icon: '🇲🇰'),
              Divider(height: 1, color: border.withValues(alpha: 0.5)),
              _LangTile(label: 'Albanian / Shqip', locale: const Locale('sq'), icon: '🇦🇱'),
            ],
          ),

          if (isPrivileged) ...[
            const SizedBox(height: 28),
            // ─── FISCAL & REPORTS ──────────────────────────
            _SectionHeader('FISCAL & REPORTS'),
            _CardGroup(
              border: border,
              surface: surface,
              children: [
                _NavTile(
                  icon: Icons.receipt_long_rounded,
                  iconColor: AppTheme.iosGreen,
                  label: 'Z-Reports / End of Day',
                  onTap: () => Navigator.pop(context, 'eod'),
                ),
                Divider(height: 1, color: border.withValues(alpha: 0.5)),
                _NavTile(
                  icon: Icons.account_balance_rounded,
                  iconColor: AppTheme.iosBlue,
                  label: 'Fiscal Settings',
                  onTap: () => Navigator.pop(context, 'fiscal'),
                ),
                Divider(height: 1, color: border.withValues(alpha: 0.5)),
                _NavTile(
                  icon: Icons.assessment_rounded,
                  iconColor: AppTheme.iosPurple,
                  label: 'Export Reports',
                  onTap: () => Navigator.pop(context, 'advanced_reports'),
                ),
              ],
            ),
          ],

          const SizedBox(height: 28),

          // ─── ABOUT ───────────────────────────────────
          _SectionHeader('ABOUT'),
          _CardGroup(
            border: border,
            surface: surface,
            children: [
              _NavTile(
                icon: Icons.info_outline_rounded,
                iconColor: AppTheme.iosBlue,
                label: 'App Version',
                trailing: Text('1.0.0',
                  style: TextStyle(color: textMuted, fontSize: 14)),
                showChevron: false,
              ),
              Divider(height: 1, color: border.withValues(alpha: 0.5)),
              _NavTile(
                icon: Icons.restaurant_rounded,
                iconColor: AppTheme.iosOrange,
                label: 'Restaurant Manager MK',
                trailing: Text('© 2025',
                  style: TextStyle(color: textMuted, fontSize: 14)),
                showChevron: false,
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ─── SIGN OUT ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _confirmLogout(context, auth),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor(context).withValues(alpha: 0.1),
                  foregroundColor: AppTheme.errorColor(context),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  shadowColor: Colors.transparent,
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign Out',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, AuthProvider auth) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.iosRedDark,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (ok == true) auth.logout();
  }

  Color _roleColor(String role, BuildContext context) {
    switch (role) {
      case 'owner': return AppTheme.iosOrange;
      case 'admin': return AppTheme.iosBlue;
      case 'developer': return AppTheme.iosPurple;
      case 'waiter': return AppTheme.iosGreen;
      case 'waiter_offtrack': return AppTheme.iosRed;
      default: return AppTheme.primaryColor(context);
    }
  }

  List<Color> _roleGradient(String role) {
    switch (role) {
      case 'owner': return [AppTheme.iosOrange, AppTheme.iosYellow];
      case 'admin': return [AppTheme.iosBlue, AppTheme.iosTeal];
      case 'developer': return [AppTheme.iosPurple, AppTheme.iosBlue];
      case 'waiter': return [AppTheme.iosGreen, AppTheme.iosTeal];
      default: return [AppTheme.iosBlue, AppTheme.iosPurple];
    }
  }
}

// ─── HELPER WIDGETS ────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: AppTheme.textMuted(context),
        )),
    );
  }
}

class _CardGroup extends StatelessWidget {
  final List<Widget> children;
  final Color border;
  final Color surface;
  const _CardGroup({required this.children, required this.border, required this.surface});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  const _NavTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
            if (trailing != null) trailing!,
            if (showChevron)
              Icon(Icons.chevron_right_rounded, size: 20,
                color: AppTheme.textMuted(context)),
          ],
        ),
      ),
    );
  }
}

class _LangTile extends StatelessWidget {
  final String label;
  final Locale locale;
  final String icon;
  const _LangTile({required this.label, required this.locale, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isSelected = context.locale == locale;
    return InkWell(
      onTap: () => context.setLocale(locale),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
            if (isSelected)
              Icon(Icons.check_rounded,
                color: AppTheme.primaryColor(context), size: 20),
          ],
        ),
      ),
    );
  }
}

class _ThemeSegmentedControl extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;
  const _ThemeSegmentedControl({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const modes = [
      (ThemeMode.light, Icons.wb_sunny_rounded, 'Light'),
      (ThemeMode.system, Icons.brightness_auto_rounded, 'Auto'),
      (ThemeMode.dark,  Icons.nightlight_round_outlined, 'Dark'),
    ];
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.surface2Color(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: modes.map((entry) {
          final (mode, icon, label) = entry;
          final isActive = current == mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.surfaceColor(context) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isActive ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4, offset: const Offset(0, 1))
                  ] : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 14,
                      color: isActive ? cs.primary : AppTheme.textMuted(context)),
                    const SizedBox(width: 4),
                    Text(label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                        color: isActive ? cs.primary : AppTheme.textMuted(context),
                      )),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
