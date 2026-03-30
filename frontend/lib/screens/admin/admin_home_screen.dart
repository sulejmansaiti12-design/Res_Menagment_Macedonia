import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_client.dart';
import 'analytics_screen.dart';
import 'advanced_reports_screen.dart';
import 'ops_kitchen_bar_screen.dart';
import 'ops_requests_screen.dart';
import 'ops_table_map_screen.dart';
import 'printer_setup_screen.dart';
import 'end_of_day_screen.dart';
import 'qr_print_screen.dart';
import 'tabs/dashboard_tab.dart';

// ─────────────────────────────────────────────────────────────
// ROUTE KEYS
// ─────────────────────────────────────────────────────────────
const _kDashboard      = 'dashboard';
const _kTableMap       = 'table_map';
const _kRequests       = 'requests';
const _kRevenue        = 'revenue';
const _kAnalytics      = 'analytics_full';
const _kZReports       = 'eod';
const _kFiskal         = 'fiskal';
const _kExportReports  = 'advanced_reports';
const _kStaff          = 'waiters';
const _kShiftHistory   = 'shift_history';
const _kMenu           = 'menu';
const _kPrinters       = 'printers';
const _kQR             = 'qr_print';
const _kSettings       = 'settings';

// ─────────────────────────────────────────────────────────────
// ADMIN HOME SCREEN
// ─────────────────────────────────────────────────────────────
class AdminHomeScreen extends StatefulWidget {
  final ApiClient apiClient;
  const AdminHomeScreen({super.key, required this.apiClient});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  String _route = _kDashboard;

  void _go(String route) => setState(() => _route = route);

  Widget _buildContent(ApiClient api, AuthProvider auth, bool isOwner) {
    switch (_route) {
      case _kDashboard:     return DashboardTab(apiClient: api, auth: auth);
      case _kTableMap:      return _MasterFloorPlanScreen(apiClient: api);
      case _kRequests:      return OpsRequestsScreen(apiClient: api);
      case _kRevenue:       return _RevenueTab(apiClient: api, isOwner: isOwner);
      case _kAnalytics:     return AnalyticsScreen(apiClient: api);
      case _kZReports:      return EndOfDayScreen(apiClient: api, isOwner: isOwner);
      case _kFiskal:        return EndOfDayScreen(apiClient: api, isOwner: isOwner);
      case _kExportReports: return AdvancedReportsScreen(apiClient: api);
      case _kStaff:         return _WaitersTab(apiClient: api);
      case _kShiftHistory:  return _ShiftHistoryTab(apiClient: api);
      case _kMenu:          return _MenuManagementTab(apiClient: api);
      case _kPrinters:      return PrinterSetupScreen(apiClient: api);
      case _kQR:            return _PrintQRTab(apiClient: api);
      case _kSettings:      return _SettingsTab();
      default:              return DashboardTab(apiClient: api, auth: auth);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthProvider>();
    final isOwner = auth.userRole == 'owner';
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final api     = widget.apiClient;
    final cs      = Theme.of(context).colorScheme;
    final isDark  = AppTheme.isDark(context);

    if (!isDesktop) {
      return Scaffold(
        backgroundColor: AppTheme.bg(context),
        appBar: _route == _kDashboard ? null : AppBar(
          backgroundColor: AppTheme.surfaceColor(context),
          title: Row(
            children: [
              Icon(Icons.restaurant_rounded, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                isOwner ? 'Owner Portal' : 'Admin Portal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textColor(context),
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _UserAvatar(name: auth.userName, isOwner: isOwner, size: 32),
            ),
          ],
        ),
        body: _buildContent(api, auth, isOwner),
        bottomNavigationBar: _MobileBottomNav(
          current: _route,
          isOwner: isOwner,
          auth: auth,
          onTap: _go,
          onMore: () => _showMoreSheet(isOwner, auth),
        ),
      );
    }

    // ── Desktop: sidebar + content ──────────────────────────
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: Row(
        children: [
          _Sidebar(
            current: _route,
            isOwner: isOwner,
            auth: auth,
            isDark: isDark,
            onTap: _go,
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
              child: _buildContent(api, auth, isOwner),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mobile bottom-sheet "More" ──────────────────────────────
  void _showMoreSheet(bool isOwner, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _MoreSheet(
        current: _route,
        isOwner: isOwner,
        auth: auth,
        onTap: (r) {
          _go(r);
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SIDEBAR
// ─────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final String current;
  final bool isOwner;
  final AuthProvider auth;
  final bool isDark;
  final ValueChanged<String> onTap;

  const _Sidebar({
    required this.current,
    required this.isOwner,
    required this.auth,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final surface = AppTheme.surfaceColor(context);
    final border = AppTheme.borderColor(context);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 272,
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.darkSurface.withValues(alpha: 0.92)
                : AppTheme.lightSurface.withValues(alpha: 0.96),
            border: Border(right: BorderSide(color: border.withValues(alpha: 0.5))),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
                // ── Brand ──────────────────────────────────
                _SidebarBrand(isOwner: isOwner),
                const SizedBox(height: 12),
                // ── User card ──────────────────────────────
                _UserCard(auth: auth, isOwner: isOwner),
                const SizedBox(height: 12),
                // ── Nav ────────────────────────────────────
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    children: [
                      if (isOwner) ...[
                        _SectionLabel('OVERVIEW'),
                        _NavItem(route: _kDashboard,     label: 'Dashboard',        icon: Icons.space_dashboard_rounded,         current: current, onTap: onTap),
                        _NavItem(route: _kAnalytics,     label: 'Sales Analytics',  icon: Icons.insights_rounded,                current: current, onTap: onTap),
                        _NavItem(route: _kStaff,         label: 'Staff',            icon: Icons.badge_rounded,                   current: current, onTap: onTap),
                        _NavItem(route: _kRevenue,       label: 'Revenue Hub',      icon: Icons.account_balance_wallet_rounded,  current: current, onTap: onTap),
                        _NavItem(route: _kExportReports, label: 'Export Reports',   icon: Icons.assessment_rounded,              current: current, onTap: onTap),
                      ] else ...[
                        _SectionLabel('COMMAND CENTER'),
                        _NavItem(route: _kDashboard,  label: 'Dashboard',       icon: Icons.space_dashboard_rounded,        current: current, onTap: onTap),
                        _NavItem(route: _kTableMap,   label: 'Floor Plan',      icon: Icons.table_restaurant_rounded,       current: current, onTap: onTap),
                        _NavItem(route: _kRequests,   label: 'Notifications',   icon: Icons.notifications_active_rounded,   current: current, onTap: onTap),
                        _SidebarDivider(),
                        _SectionLabel('FINANCIALS & FISCAL'),
                        _NavItem(route: _kRevenue,       label: 'Revenue & Payments', icon: Icons.account_balance_wallet_rounded, current: current, onTap: onTap),
                        _NavItem(route: _kAnalytics,     label: 'Sales Analytics',    icon: Icons.insights_rounded,               current: current, onTap: onTap),
                        _NavItem(route: _kZReports,      label: 'Z-Reports (EOD)',     icon: Icons.summarize_rounded,              current: current, onTap: onTap),
                        _NavItem(route: _kFiskal,        label: 'Fiskal Settings',     icon: Icons.receipt_long_rounded,           current: current, onTap: onTap, accent: AppTheme.iosGreen),
                        _NavItem(route: _kExportReports, label: 'Export Reports',      icon: Icons.assessment_rounded,             current: current, onTap: onTap),
                        _SidebarDivider(),
                        _SectionLabel('TEAM'),
                        _NavItem(route: _kStaff,        label: 'Staff Management', icon: Icons.badge_rounded,    current: current, onTap: onTap),
                        _NavItem(route: _kShiftHistory, label: 'Shift History',    icon: Icons.history_rounded,  current: current, onTap: onTap),
                        _SidebarDivider(),
                        _SectionLabel('CONFIGURATION'),
                        _NavItem(route: _kMenu,     label: 'Menu Items',    icon: Icons.fastfood_rounded,   current: current, onTap: onTap),
                        _NavItem(route: _kPrinters, label: 'Printer Setup', icon: Icons.print_rounded,      current: current, onTap: onTap),
                        _NavItem(route: _kQR,       label: 'QR Codes',      icon: Icons.qr_code_rounded,    current: current, onTap: onTap),
                      ],
                      const SizedBox(height: 8),
                      _SidebarDivider(),
                      _NavItem(route: _kSettings, label: 'Settings', icon: Icons.settings_rounded, current: current, onTap: onTap),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                // ── Logout ─────────────────────────────────
                _LogoutButton(auth: auth),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SIDEBAR BRAND
// ─────────────────────────────────────────────────────────────
class _SidebarBrand extends StatelessWidget {
  final bool isOwner;
  const _SidebarBrand({required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, AppTheme.iosGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: cs.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: const Icon(Icons.restaurant_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('POS Manager',
                  style: TextStyle(color: AppTheme.textColor(context), fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  isOwner ? 'Owner Portal' : 'Admin Portal',
                  style: TextStyle(color: AppTheme.textMuted(context), fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// USER CARD
// ─────────────────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final AuthProvider auth;
  final bool isOwner;
  const _UserCard({required this.auth, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final roleColor = isOwner ? AppTheme.iosOrange : AppTheme.iosBlue;
    final roleLabel = isOwner ? 'OWNER' : 'ADMIN';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bg(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor(context).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          _UserAvatar(name: auth.userName, isOwner: isOwner, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(auth.userName,
                  style: TextStyle(color: AppTheme.textColor(context), fontWeight: FontWeight.w700, fontSize: 13),
                  overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(roleLabel,
                    style: TextStyle(color: roleColor, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// USER AVATAR
// ─────────────────────────────────────────────────────────────
class _UserAvatar extends StatelessWidget {
  final String name;
  final bool isOwner;
  final double size;
  const _UserAvatar({required this.name, required this.isOwner, required this.size});

  @override
  Widget build(BuildContext context) {
    final color = isOwner ? AppTheme.iosOrange : AppTheme.iosBlue;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'A',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.45),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SIDEBAR SECTION LABEL
// ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 4, top: 8),
      child: Text(
        text,
        style: TextStyle(
          color: AppTheme.textMuted(context).withValues(alpha: 0.55),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SIDEBAR DIVIDER
// ─────────────────────────────────────────────────────────────
class _SidebarDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: AppTheme.borderColor(context).withValues(alpha: 0.5),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// NAV ITEM
// ─────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final String route;
  final String label;
  final IconData icon;
  final String current;
  final ValueChanged<String> onTap;
  final Color? accent;

  const _NavItem({
    required this.route,
    required this.label,
    required this.icon,
    required this.current,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = current == route;
    final iconColor = accent ?? cs.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(route),
          borderRadius: BorderRadius.circular(10),
          hoverColor: cs.primary.withValues(alpha: 0.04),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? cs.primary.withValues(alpha: 0.10) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected ? Border.all(color: cs.primary.withValues(alpha: 0.15)) : null,
            ),
            child: Row(
              children: [
                // Active indicator bar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 3,
                  height: isSelected ? 18 : 0,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? iconColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Icon(
                  icon,
                  size: 19,
                  color: isSelected ? iconColor : AppTheme.textMuted(context).withValues(alpha: 0.6),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? AppTheme.textColor(context) : AppTheme.textMuted(context),
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// LOGOUT BUTTON
// ─────────────────────────────────────────────────────────────
class _LogoutButton extends StatelessWidget {
  final AuthProvider auth;
  const _LogoutButton({required this.auth});

  @override
  Widget build(BuildContext context) {
    final errColor = AppTheme.errorColor(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => auth.logout(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
              color: errColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: errColor.withValues(alpha: 0.10)),
            ),
            child: Row(
              children: [
                Icon(Icons.logout_rounded, color: errColor.withValues(alpha: 0.8), size: 18),
                const SizedBox(width: 10),
                Text('Sign Out',
                  style: TextStyle(color: errColor.withValues(alpha: 0.85), fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MOBILE BOTTOM NAV
// ─────────────────────────────────────────────────────────────
class _MobileBottomNav extends StatelessWidget {
  final String current;
  final bool isOwner;
  final AuthProvider auth;
  final ValueChanged<String> onTap;
  final VoidCallback onMore;

  const _MobileBottomNav({
    required this.current,
    required this.isOwner,
    required this.auth,
    required this.onTap,
    required this.onMore,
  });

  int get _index {
    if (current == _kDashboard) return 0;
    if (current == _kTableMap)  return 1;
    if (current == _kRevenue)   return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BottomNavigationBar(
      backgroundColor: AppTheme.surfaceColor(context),
      selectedItemColor: cs.primary,
      unselectedItemColor: AppTheme.textMuted(context),
      type: BottomNavigationBarType.fixed,
      currentIndex: _index,
      selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
      elevation: 0,
      onTap: (i) {
        if (i == 0) onTap(_kDashboard);
        else if (i == 1) onTap(_kTableMap);
        else if (i == 2) onTap(_kRevenue);
        else onMore();
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.space_dashboard_rounded), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.table_restaurant_rounded), label: 'Floors'),
        BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: 'Revenue'),
        BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'More'),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MORE SHEET (mobile)
// ─────────────────────────────────────────────────────────────
class _MoreSheet extends StatelessWidget {
  final String current;
  final bool isOwner;
  final AuthProvider auth;
  final ValueChanged<String> onTap;

  const _MoreSheet({
    required this.current,
    required this.isOwner,
    required this.auth,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = AppTheme.surfaceColor(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppTheme.borderColor(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(
              children: [
                Text('More', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (isOwner) ...[
                  _SheetSection('OVERVIEW'),
                  _SheetItem(route: _kAnalytics,     label: 'Sales Analytics',  icon: Icons.insights_rounded,               current: current, onTap: onTap),
                  _SheetItem(route: _kStaff,         label: 'Staff',            icon: Icons.badge_rounded,                  current: current, onTap: onTap),
                  _SheetItem(route: _kExportReports, label: 'Export Reports',   icon: Icons.assessment_rounded,             current: current, onTap: onTap),
                ] else ...[
                  _SheetSection('OPERATIONS'),
                  _SheetItem(route: _kRequests,  label: 'Notifications', icon: Icons.notifications_active_rounded, current: current, onTap: onTap),
                  _SheetSection('FINANCIALS & FISCAL'),
                  _SheetItem(route: _kAnalytics,     label: 'Sales Analytics',    icon: Icons.insights_rounded,               current: current, onTap: onTap),
                  _SheetItem(route: _kZReports,      label: 'Z-Reports (EOD)',     icon: Icons.summarize_rounded,              current: current, onTap: onTap),
                  _SheetItem(route: _kFiskal,        label: 'Fiskal Settings',     icon: Icons.receipt_long_rounded,           current: current, onTap: onTap, accent: AppTheme.iosGreen),
                  _SheetItem(route: _kExportReports, label: 'Export Reports',      icon: Icons.assessment_rounded,             current: current, onTap: onTap),
                  _SheetSection('TEAM'),
                  _SheetItem(route: _kStaff,        label: 'Staff Management', icon: Icons.badge_rounded,   current: current, onTap: onTap),
                  _SheetItem(route: _kShiftHistory, label: 'Shift History',    icon: Icons.history_rounded, current: current, onTap: onTap),
                  _SheetSection('CONFIGURATION'),
                  _SheetItem(route: _kMenu,     label: 'Menu Items',    icon: Icons.fastfood_rounded,  current: current, onTap: onTap),
                  _SheetItem(route: _kPrinters, label: 'Printer Setup', icon: Icons.print_rounded,     current: current, onTap: onTap),
                  _SheetItem(route: _kQR,       label: 'QR Codes',      icon: Icons.qr_code_rounded,   current: current, onTap: onTap),
                ],
                _SheetSection('ACCOUNT'),
                _SheetItem(route: _kSettings, label: 'Settings', icon: Icons.settings_rounded, current: current, onTap: onTap),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () { Navigator.pop(context); auth.logout(); },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor(context),
                      side: BorderSide(color: AppTheme.errorColor(context).withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Sign Out'),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetSection extends StatelessWidget {
  final String text;
  const _SheetSection(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4, left: 4),
      child: Text(text,
        style: TextStyle(
          color: AppTheme.textMuted(context).withValues(alpha: 0.5),
          fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.6,
        ),
      ),
    );
  }
}

class _SheetItem extends StatelessWidget {
  final String route, label;
  final IconData icon;
  final String current;
  final ValueChanged<String> onTap;
  final Color? accent;

  const _SheetItem({
    required this.route,
    required this.label,
    required this.icon,
    required this.current,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = current == route;
    final iconColor = accent ?? cs.primary;
    return ListTile(
      leading: Icon(icon, color: isSelected ? iconColor : AppTheme.textMuted(context), size: 22),
      title: Text(label,
        style: TextStyle(
          color: isSelected ? AppTheme.textColor(context) : AppTheme.textMuted(context),
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 15,
        ),
      ),
      tileColor: isSelected ? cs.primary.withValues(alpha: 0.07) : Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () => onTap(route),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SETTINGS TAB
// ─────────────────────────────────────────────────────────────
class _SettingsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthProvider>();
    final theme   = context.watch<ThemeProvider>();
    final cs      = Theme.of(context).colorScheme;
    final isDark  = AppTheme.isDark(context);
    final surface = AppTheme.surfaceColor(context);
    final bg      = AppTheme.bg(context);

    return Scaffold(
      backgroundColor: bg,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Header ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text('Settings',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor(context),
              )),
          ),

          // ── Appearance ─────────────────────────────────
          _SettingsGroup(
            label: 'APPEARANCE',
            children: [
              _SettingsTile(
                icon: Icons.brightness_6_rounded,
                title: 'Theme',
                subtitle: theme.isDark ? 'Dark Mode' : theme.isLight ? 'Light Mode' : 'System',
                trailing: _ThemeSegmentedControl(provider: theme),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Account ────────────────────────────────────
          _SettingsGroup(
            label: 'ACCOUNT',
            children: [
              _SettingsTile(
                icon: Icons.person_rounded,
                title: auth.userName,
                subtitle: auth.userRole.toUpperCase(),
              ),
              _SettingsTile(
                icon: Icons.logout_rounded,
                title: 'Sign Out',
                titleColor: AppTheme.errorColor(context),
                iconColor: AppTheme.errorColor(context),
                onTap: () => auth.logout(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Fiscal ─────────────────────────────────────
          _SettingsGroup(
            label: 'FISCAL & REPORTING',
            children: [
              _SettingsTile(
                icon: Icons.receipt_long_rounded,
                iconColor: AppTheme.iosGreen,
                title: 'Fiscal Settings',
                subtitle: 'Configure fiscal receipt parameters',
              ),
              _SettingsTile(
                icon: Icons.summarize_rounded,
                title: 'Z-Reports',
                subtitle: 'End of day reports',
              ),
              _SettingsTile(
                icon: Icons.print_rounded,
                title: 'Printer Setup',
                subtitle: 'Thermal printer configuration',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── App info ───────────────────────────────────
          _SettingsGroup(
            label: 'APP',
            children: [
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'Restaurant Manager',
                subtitle: 'Version 1.0.0',
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String label;
  final List<Widget> children;
  const _SettingsGroup({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(label,
            style: TextStyle(
              color: AppTheme.textMuted(context).withValues(alpha: 0.55),
              fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4,
            )),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderColor(context).withValues(alpha: 0.5)),
          ),
          child: Column(
            children: children.asMap().entries.map((e) {
              final isLast = e.key == children.length - 1;
              return Column(
                children: [
                  e.value,
                  if (!isLast) Divider(
                    height: 1, thickness: 0.5,
                    indent: 52,
                    color: AppTheme.borderColor(context).withValues(alpha: 0.5),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? titleColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: (iconColor ?? cs.primary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor ?? cs.primary, size: 18),
      ),
      title: Text(title,
        style: TextStyle(
          color: titleColor ?? AppTheme.textColor(context),
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, style: TextStyle(color: AppTheme.textMuted(context), fontSize: 12))
          : null,
      trailing: trailing ?? (onTap != null ? Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted(context), size: 20) : null),
    );
  }
}

class _ThemeSegmentedControl extends StatelessWidget {
  final ThemeProvider provider;
  const _ThemeSegmentedControl({required this.provider});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(value: ThemeMode.light,  icon: Icon(Icons.light_mode_rounded, size: 16),  label: Text('Light')),
        ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.auto_mode_rounded, size: 16),   label: Text('Auto')),
        ButtonSegment(value: ThemeMode.dark,   icon: Icon(Icons.dark_mode_rounded, size: 16),   label: Text('Dark')),
      ],
      selected: {provider.themeMode},
      onSelectionChanged: (s) => provider.setTheme(s.first),
      style: ButtonStyle(
        textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 6, vertical: 8)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MASTER FLOOR PLAN
// ─────────────────────────────────────────────────────────────
class _MasterFloorPlanScreen extends StatelessWidget {
  final ApiClient apiClient;
  const _MasterFloorPlanScreen({required this.apiClient});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppTheme.bg(context),
        appBar: AppBar(
          backgroundColor: AppTheme.surfaceColor(context),
          title: Text('Master Floor Plan', style: TextStyle(color: AppTheme.textColor(context))),
          bottom: TabBar(
            tabs: const [
              Tab(text: 'LIVE MONITOR', icon: Icon(Icons.table_restaurant_rounded)),
              Tab(text: 'SETUP TABLES', icon: Icon(Icons.table_bar_rounded)),
              Tab(text: 'ZONES',        icon: Icon(Icons.grid_view_rounded)),
            ],
            indicatorColor: cs.primary,
            labelColor: cs.primary,
            unselectedLabelColor: AppTheme.textMuted(context),
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            OpsTableMapScreen(apiClient: apiClient),
            _TablesSetupTab(apiClient: apiClient),
            _ZonesSetupTab(apiClient: apiClient),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SHIFT HISTORY STUB
// ─────────────────────────────────────────────────────────────
class _ShiftHistoryTab extends StatelessWidget {
  final ApiClient apiClient;
  const _ShiftHistoryTab({required this.apiClient});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor(context),
        title: Text('Shift History', style: TextStyle(color: AppTheme.textColor(context))),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 64, color: AppTheme.textMuted(context)),
            const SizedBox(height: 16),
            Text('No shift history yet', style: TextStyle(color: AppTheme.textMuted(context), fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// REVENUE TAB STUB
// ─────────────────────────────────────────────────────────────
class _RevenueTab extends StatelessWidget {
  final ApiClient apiClient;
  final bool isOwner;
  const _RevenueTab({required this.apiClient, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor(context),
        title: Text('Revenue & Payments', style: TextStyle(color: AppTheme.textColor(context))),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_rounded, size: 64, color: cs.primary),
            const SizedBox(height: 16),
            Text('Revenue data loading...', style: TextStyle(color: AppTheme.textMuted(context), fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PRINT QR STUB
// ─────────────────────────────────────────────────────────────
class _PrintQRTab extends StatelessWidget {
  final ApiClient apiClient;
  const _PrintQRTab({required this.apiClient});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor(context),
        title: Text('QR Codes', style: TextStyle(color: AppTheme.textColor(context))),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_rounded, size: 64, color: AppTheme.textMuted(context)),
            const SizedBox(height: 16),
            Text('QR management', style: TextStyle(color: AppTheme.textMuted(context), fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WAITERS TAB
// ─────────────────────────────────────────────────────────────
class _WaitersTab extends StatefulWidget {
  final ApiClient apiClient;
  const _WaitersTab({required this.apiClient});

  @override
  State<_WaitersTab> createState() => _WaitersTabState();
}

class _WaitersTabState extends State<_WaitersTab> {
  List<Map<String, dynamic>> _waiters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final res = await widget.apiClient.get('/admin/waiters');
      setState(() {
        _waiters = List<Map<String, dynamic>>.from(
          (res['data']['waiters'] as List).map((w) => Map<String, dynamic>.from(w as Map)),
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor(context),
        title: Text('Staff Management', style: TextStyle(color: AppTheme.textColor(context))),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: cs.primary,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: cs.primary, strokeWidth: 2.5))
            : _waiters.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.badge_rounded, size: 64, color: AppTheme.textMuted(context)),
                        const SizedBox(height: 16),
                        Text('No staff registered', style: TextStyle(color: AppTheme.textMuted(context), fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _waiters.length,
                    itemBuilder: (ctx, i) => _WaiterCard(
                      waiter: _waiters[i],
                      apiClient: widget.apiClient,
                      onRefresh: _load,
                    ),
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Staff'),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final nameC = TextEditingController();
    final userC = TextEditingController();
    final passC = TextEditingController();
    String role = 'waiter';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Add Staff Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Full Name')),
              const SizedBox(height: 12),
              TextField(controller: userC, decoration: const InputDecoration(labelText: 'Username')),
              const SizedBox(height: 12),
              TextField(controller: passC, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'waiter', child: Text('Standard Waiter')),
                  DropdownMenuItem(value: 'waiter_offtrack', child: Text('Waiter (Off-Track)')),
                ],
                onChanged: (v) => ss(() => role = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await widget.apiClient.post('/admin/waiters', body: {
                    'name': nameC.text, 'username': userC.text,
                    'password': passC.text, 'role': role,
                  });
                  _load();
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor(context)),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WAITER CARD
// ─────────────────────────────────────────────────────────────
class _WaiterCard extends StatelessWidget {
  final Map<String, dynamic> waiter;
  final ApiClient apiClient;
  final VoidCallback onRefresh;
  const _WaiterCard({required this.waiter, required this.apiClient, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = waiter['activeShift'] as Map<String, dynamic>?;
    final isOn = active != null;
    final isOT = waiter['role'] == 'waiter_offtrack';
    final name = waiter['name'] as String? ?? 'Staff';
    final zone = (active?['zone'] as Map?)?['name'] ?? 'Unknown Zone';
    final cash = active?['totalCashCollected']?.toString() ?? '0';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: AppTheme.surfaceColor(context),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isOn ? AppTheme.successColor(context) : AppTheme.textMuted(context),
          child: Text(name[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        title: Row(
          children: [
            Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textColor(context))),
            if (isOT) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor(context).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('OFF-TRACK',
                  style: TextStyle(fontSize: 9, color: AppTheme.errorColor(context), fontWeight: FontWeight.w800)),
              ),
            ],
          ],
        ),
        subtitle: Text(
          isOn ? '$zone • $cash MKD' : 'Offline',
          style: TextStyle(color: AppTheme.textMuted(context), fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                if (isOn) ...[
                  Row(
                    children: [
                      _StatChip('Fiscal',    active?['totalFiscal']?.toString() ?? '0',    AppTheme.successColor(context)),
                      const SizedBox(width: 8),
                      _StatChip('Off-Track', active?['totalOffTrack']?.toString() ?? '0',  AppTheme.errorColor(context)),
                      const SizedBox(width: 8),
                      _StatChip('Cash',      cash,                                          cs.primary),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _edit(context),
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Edit'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _delete(context),
                      icon: Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.errorColor(context)),
                      label: Text('Remove', style: TextStyle(color: AppTheme.errorColor(context))),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _edit(BuildContext context) {
    final nameC = TextEditingController(text: waiter['name'] as String? ?? '');
    final userC = TextEditingController(text: waiter['username'] as String? ?? '');
    final passC = TextEditingController();
    String role = (waiter['role'] as String?) ?? 'waiter';
    if (role != 'waiter' && role != 'waiter_offtrack') role = 'waiter';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Edit Staff Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Full Name')),
              const SizedBox(height: 12),
              TextField(controller: userC, decoration: const InputDecoration(labelText: 'Username')),
              const SizedBox(height: 12),
              TextField(controller: passC, obscureText: true, decoration: const InputDecoration(labelText: 'New Password (leave blank to keep)')),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'waiter', child: Text('Standard Waiter')),
                  DropdownMenuItem(value: 'waiter_offtrack', child: Text('Waiter (Off-Track)')),
                ],
                onChanged: (v) => ss(() => role = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final body = <String, dynamic>{'name': nameC.text, 'username': userC.text, 'role': role};
                  if (passC.text.isNotEmpty) body['password'] = passC.text;
                  await apiClient.put('/admin/waiters/${waiter['id']}', body: body);
                  onRefresh();
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor(context)),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Staff'),
        content: const Text('Deactivate this staff account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor(context)),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await apiClient.delete('/admin/waiters/${waiter['id']}');
        onRefresh();
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor(context)),
        );
      }
    }
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: AppTheme.textMuted(context))),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ZONES SETUP TAB
// ─────────────────────────────────────────────────────────────
class _ZonesSetupTab extends StatefulWidget {
  final ApiClient apiClient;
  const _ZonesSetupTab({required this.apiClient});
  @override
  State<_ZonesSetupTab> createState() => _ZonesSetupTabState();
}

class _ZonesSetupTabState extends State<_ZonesSetupTab> {
  List<Map<String, dynamic>> _zones = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await widget.apiClient.get('/zones');
      setState(() {
        _zones = List<Map<String, dynamic>>.from(
          (res['data']['zones'] as List).map((z) => Map<String, dynamic>.from(z as Map)));
        _loading = false;
      });
    } catch (e) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: RefreshIndicator(
        onRefresh: _load,
        color: cs.primary,
        child: _loading
            ? Center(child: CircularProgressIndicator(color: cs.primary, strokeWidth: 2.5))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _zones.length,
                itemBuilder: (ctx, i) {
                  final z = _zones[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    color: AppTheme.surfaceColor(context),
                    child: ListTile(
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: cs.secondary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.place_rounded, color: cs.secondary, size: 20),
                      ),
                      title: Text(z['name'] as String? ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textColor(context))),
                      subtitle: Text('Welcome: ${z['welcomeMessage'] ?? 'Not set'}', style: TextStyle(color: AppTheme.textMuted(context), fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(onPressed: () => _edit(z), icon: Icon(Icons.edit_rounded, color: cs.primary, size: 18)),
                          IconButton(onPressed: () => _delete(z['id'] as String), icon: Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor(context), size: 18)),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Add Zone'),
      ),
    );
  }

  void _add() {
    final nC = TextEditingController();
    final mC = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Add Zone'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nC, decoration: const InputDecoration(labelText: 'Zone Name')),
        const SizedBox(height: 12),
        TextField(controller: mC, decoration: const InputDecoration(labelText: 'Welcome Message'), maxLines: 2),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          Navigator.pop(ctx);
          await widget.apiClient.post('/zones', body: {'name': nC.text, 'welcomeMessage': mC.text});
          _load();
        }, child: const Text('Add')),
      ],
    ));
  }

  void _edit(Map<String, dynamic> zone) {
    final nC = TextEditingController(text: zone['name'] as String? ?? '');
    final mC = TextEditingController(text: zone['welcomeMessage'] as String? ?? '');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Edit Zone'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nC, decoration: const InputDecoration(labelText: 'Zone Name')),
        const SizedBox(height: 12),
        TextField(controller: mC, decoration: const InputDecoration(labelText: 'Welcome Message'), maxLines: 2),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          Navigator.pop(ctx);
          await widget.apiClient.put('/zones/${zone['id']}', body: {'name': nC.text, 'welcomeMessage': mC.text});
          _load();
        }, child: const Text('Save')),
      ],
    ));
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Zone'),
      content: const Text('This will also hide all tables inside.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor(context)),
          child: const Text('Delete'),
        ),
      ],
    ));
    if (ok == true) { await widget.apiClient.delete('/zones/$id'); _load(); }
  }
}

// ─────────────────────────────────────────────────────────────
// TABLES SETUP TAB
// ─────────────────────────────────────────────────────────────
class _TablesSetupTab extends StatefulWidget {
  final ApiClient apiClient;
  const _TablesSetupTab({required this.apiClient});
  @override
  State<_TablesSetupTab> createState() => _TablesSetupTabState();
}

class _TablesSetupTabState extends State<_TablesSetupTab> {
  List<Map<String, dynamic>> _zones = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await widget.apiClient.get('/zones');
      setState(() {
        _zones = List<Map<String, dynamic>>.from(
          (res['data']['zones'] as List).map((z) => Map<String, dynamic>.from(z as Map)));
        _loading = false;
      });
    } catch (e) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _deleteTable(String id) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Table'),
      content: const Text('Remove this physical table?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor(context)),
          child: const Text('Delete'),
        ),
      ],
    ));
    if (ok == true) { await widget.apiClient.delete('/tables/$id'); _load(); }
  }

  void _addTable(String zoneId) {
    final nC = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Add Table'),
      content: TextField(controller: nC, decoration: const InputDecoration(labelText: 'Table Name (e.g. Table 14)')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          Navigator.pop(ctx);
          await widget.apiClient.post('/tables', body: {'name': nC.text, 'zoneId': zoneId});
          _load();
        }, child: const Text('Add')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: RefreshIndicator(
        onRefresh: _load,
        color: cs.primary,
        child: _loading
            ? Center(child: CircularProgressIndicator(color: cs.primary, strokeWidth: 2.5))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _zones.length,
                itemBuilder: (ctx, i) {
                  final zone = _zones[i];
                  final tables = zone['tables'] as List? ?? [];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderColor(context).withValues(alpha: 0.5)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.place_rounded, color: cs.secondary, size: 20),
                                const SizedBox(width: 8),
                                Text(zone['name'] as String? ?? '',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textColor(context))),
                              ],
                            ),
                            TextButton.icon(
                              onPressed: () => _addTable(zone['id'] as String),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Add Table'),
                            ),
                          ],
                        ),
                        Divider(height: 20, color: AppTheme.borderColor(context).withValues(alpha: 0.4)),
                        if (tables.isEmpty)
                          Text('No tables in this zone.',
                            style: TextStyle(color: AppTheme.textMuted(context), fontStyle: FontStyle.italic))
                        else
                          Wrap(
                            spacing: 8, runSpacing: 8,
                            children: tables.map<Widget>((t) {
                              final table = Map<String, dynamic>.from(t as Map);
                              return Container(
                                padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.bg(context),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppTheme.borderColor(context).withValues(alpha: 0.6)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.table_restaurant_rounded, size: 14, color: AppTheme.textMuted(context)),
                                    const SizedBox(width: 6),
                                    Text(table['name'] as String? ?? '',
                                      style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textColor(context), fontSize: 13)),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => _deleteTable(table['id'] as String),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.all(3),
                                        child: Icon(Icons.close_rounded, size: 14, color: AppTheme.errorColor(context)),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MENU MANAGEMENT TAB
// ─────────────────────────────────────────────────────────────
class _MenuManagementTab extends StatefulWidget {
  final ApiClient apiClient;
  const _MenuManagementTab({required this.apiClient});

  @override
  State<_MenuManagementTab> createState() => _MenuManagementTabState();
}

class _MenuManagementTabState extends State<_MenuManagementTab> {
  List<Map<String, dynamic>> _cats = [];
  List<Map<String, dynamic>> _dests = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final cR = await widget.apiClient.get('/categories');
      final dR = await widget.apiClient.get('/destinations');
      setState(() {
        _cats  = List<Map<String, dynamic>>.from((cR['data']['categories'] as List).map((c) => Map<String, dynamic>.from(c as Map)));
        _dests = List<Map<String, dynamic>>.from((dR['data']['destinations'] as List).map((d) => Map<String, dynamic>.from(d as Map)));
        _loading = false;
      });
    } catch (e) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor(context),
        title: Text('Menu Management', style: TextStyle(color: AppTheme.textColor(context))),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: cs.primary,
        child: _loading
            ? Center(child: CircularProgressIndicator(color: cs.primary, strokeWidth: 2.5))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Order Destinations ──────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Order Destinations',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textColor(context))),
                      IconButton(
                        onPressed: _addDest,
                        icon: Icon(Icons.add_circle_rounded, color: cs.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _dests.map((d) => Chip(
                      label: Text(d['name'] as String),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () async {
                        await widget.apiClient.delete('/destinations/${d['id']}');
                        _load();
                      },
                    )).toList(),
                  ),
                  const SizedBox(height: 24),
                  // ── Categories ─────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Menu Categories & Items',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textColor(context))),
                      IconButton(
                        onPressed: _addCat,
                        icon: Icon(Icons.add_circle_rounded, color: cs.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._cats.map(_buildCategoryCard),
                ],
              ),
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> cat) {
    final cs = Theme.of(context).colorScheme;
    final items = cat['items'] as List? ?? [];
    final dest = cat['destination'] as Map?;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: AppTheme.surfaceColor(context),
      child: ExpansionTile(
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(9)),
          child: Icon(Icons.category_rounded, color: cs.primary, size: 18),
        ),
        title: Text(cat['name'] as String? ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textColor(context))),
        subtitle: Text('→ ${dest?['name'] ?? 'Unknown'} • ${items.length} items',
          style: TextStyle(color: AppTheme.textMuted(context), fontSize: 12)),
        trailing: IconButton(
          onPressed: () => _addItem(cat['id'] as String),
          icon: Icon(Icons.add_circle_outline_rounded, color: cs.secondary, size: 20),
          tooltip: 'Add item',
        ),
        children: items.map((item) {
          final m = item as Map;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: Text(m['name'] as String? ?? '', style: TextStyle(color: AppTheme.textColor(context), fontSize: 14)),
            subtitle: Text(m['description'] as String? ?? '', style: TextStyle(color: AppTheme.textMuted(context), fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${m['price']} MKD',
                  style: TextStyle(fontWeight: FontWeight.bold, color: cs.secondary, fontSize: 13)),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => _deleteItem(m['id'] as String),
                  icon: Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor(context), size: 18),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _addDest() {
    final c = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Add Destination'),
      content: TextField(controller: c, decoration: const InputDecoration(labelText: 'e.g. Kitchen, Bar')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          Navigator.pop(ctx);
          await widget.apiClient.post('/destinations', body: {'name': c.text});
          _load();
        }, child: const Text('Add')),
      ],
    ));
  }

  void _addCat() {
    final nC = TextEditingController();
    String? destId = _dests.isNotEmpty ? _dests[0]['id'] as String : null;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, ss) => AlertDialog(
        title: const Text('Add Category'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nC, decoration: const InputDecoration(labelText: 'Category Name')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: destId,
            decoration: const InputDecoration(labelText: 'Destination'),
            items: _dests.map((d) => DropdownMenuItem<String>(
              value: d['id'] as String, child: Text(d['name'] as String))).toList(),
            onChanged: (v) => ss(() => destId = v),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () async {
            Navigator.pop(ctx);
            await widget.apiClient.post('/categories', body: {'name': nC.text, 'destinationId': destId});
            _load();
          }, child: const Text('Add')),
        ],
      ),
    ));
  }

  void _addItem(String catId) {
    final nC = TextEditingController();
    final dC = TextEditingController();
    final pC = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Add Menu Item'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nC, decoration: const InputDecoration(labelText: 'Item Name')),
        const SizedBox(height: 12),
        TextField(controller: dC, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
        const SizedBox(height: 12),
        TextField(controller: pC, decoration: const InputDecoration(labelText: 'Price (MKD)'), keyboardType: TextInputType.number),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          Navigator.pop(ctx);
          await widget.apiClient.post('/menu-items', body: {
            'name': nC.text, 'description': dC.text,
            'price': double.tryParse(pC.text) ?? 0,
            'categoryId': catId,
          });
          _load();
        }, child: const Text('Add')),
      ],
    ));
  }

  Future<void> _deleteItem(String id) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Menu Item'),
      content: const Text('Remove this item from the menu?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor(context)),
          child: const Text('Delete'),
        ),
      ],
    ));
    if (ok == true) {
      try {
        await widget.apiClient.delete('/menu-items/$id');
        _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor(context)));
      }
    }
  }
}
