import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../config/app_theme.dart';
import '../../services/api_client.dart';
import '../../providers/auth_provider.dart';
import '../shared/settings_screen.dart';
import 'analytics_screen.dart';
import 'advanced_reports_screen.dart';
import 'ops_kitchen_bar_screen.dart';
import 'ops_requests_screen.dart';
import 'ops_table_map_screen.dart';
import 'printer_setup_screen.dart';
import 'end_of_day_screen.dart';
import 'qr_print_screen.dart';
import 'tabs/dashboard_tab.dart';

class AdminHomeScreen extends StatefulWidget {
  final ApiClient apiClient;
  const AdminHomeScreen({super.key, required this.apiClient});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  String _currentRoute = 'dashboard';

  Widget _buildCurrentScreen(ApiClient api, AuthProvider auth, bool isOwner) {
    switch (_currentRoute) {
      case 'dashboard':        return DashboardTab(apiClient: api, auth: auth);
      case 'table_map':        return _MasterFloorPlanScreen(apiClient: api);
      case 'requests':         return OpsRequestsScreen(apiClient: api);
      case 'waiters':          return _WaitersTab(apiClient: api);
      case 'shift_history':    return _ShiftHistoryTab(apiClient: api);
      case 'order_history':    return _OrderHistoryTab(apiClient: api);
      case 'revenue':          return _RevenueTab(apiClient: api, isOwner: isOwner);
      case 'analytics_full':   return AnalyticsScreen(apiClient: api);
      case 'eod':              return EndOfDayScreen(apiClient: api, isOwner: isOwner);
      case 'advanced_reports': return AdvancedReportsScreen(apiClient: api);
      case 'menu':             return _MenuManagementTab(apiClient: api);
      case 'printers':         return PrinterSetupScreen(apiClient: api);
      case 'qr_print':         return _PrintQRTab(apiClient: api);
      default:                 return DashboardTab(apiClient: api, auth: auth);
    }
  }

  void _openSettings() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const AppSettingsScreen()),
    );
    if (result != null && mounted) {
      setState(() => _currentRoute = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isOwner = auth.userRole == 'owner';
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final isDark = AppTheme.isDark(context);

    // iOS-adaptive colors
    final sidebarBg = isDark
      ? AppTheme.darkSurface.withValues(alpha: 0.92)
      : AppTheme.lightSurface.withValues(alpha: 0.92);
    final sidebarBorder = AppTheme.borderColor(context);
    final contentBg = AppTheme.bg(context);

    if (!isDesktop) {
      return Scaffold(
        backgroundColor: contentBg,
        appBar: _currentRoute == 'dashboard' ? null : AppBar(
          backgroundColor: AppTheme.surfaceColor(context),
          title: Row(
            children: [
              Icon(Icons.restaurant_rounded,
                color: AppTheme.primaryColor(context), size: 18),
              const SizedBox(width: 8),
              Text(isOwner ? 'Owner Dashboard' : 'Admin Dashboard',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _openSettings,
              icon: Icon(Icons.person_circle_outline,
                color: AppTheme.primaryColor(context), size: 26),
              tooltip: 'Settings',
            ),
          ],
        ),
        body: _buildCurrentScreen(widget.apiClient, auth, isOwner),
        bottomNavigationBar: _buildMobileBottomNav(isOwner, auth),
      );
    }

    return Scaffold(
      backgroundColor: contentBg,
      body: Row(
        children: [
          // ═══ SIDEBAR ════════════════════════════════
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: 272,
                decoration: BoxDecoration(
                  color: sidebarBg,
                  border: Border(right: BorderSide(
                    color: sidebarBorder.withValues(alpha: 0.5))),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Brand
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor(context).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppTheme.iosBlue, AppTheme.iosPurple],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.restaurant_rounded,
                              color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('POS Manager',
                                  style: TextStyle(
                                    color: AppTheme.textColor(context),
                                    fontWeight: FontWeight.w800, fontSize: 14)),
                                Text(isOwner ? 'Owner Portal' : 'Admin Portal',
                                  style: TextStyle(
                                    color: AppTheme.textMuted(context),
                                    fontSize: 11, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // User profile
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.surface2Color(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.borderColor(context).withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                              color: isOwner
                                ? AppTheme.iosOrange.withValues(alpha: 0.2)
                                : AppTheme.iosBlue.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                auth.userName.isNotEmpty
                                  ? auth.userName[0].toUpperCase() : 'A',
                                style: TextStyle(
                                  color: isOwner ? AppTheme.iosOrange : AppTheme.iosBlue,
                                  fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(auth.userName,
                                  style: TextStyle(
                                    color: AppTheme.textColor(context),
                                    fontWeight: FontWeight.w700, fontSize: 13),
                                  overflow: TextOverflow.ellipsis),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isOwner
                                      ? AppTheme.iosOrange.withValues(alpha: 0.12)
                                      : AppTheme.iosBlue.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isOwner ? 'OWNER' : 'ADMIN',
                                    style: TextStyle(
                                      color: isOwner ? AppTheme.iosOrange : AppTheme.iosBlue,
                                      fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Navigation
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        children: [
                          // ── COMMAND CENTER
                          _sectionLabel('COMMAND CENTER'),
                          _navItem('dashboard', 'Dashboard',
                            Icons.space_dashboard_rounded),
                          _navItem('table_map', 'Floor Plan',
                            Icons.table_restaurant_rounded),
                          _navItem('requests', 'Notifications',
                            Icons.notifications_rounded),

                          _divider(),

                          // ── FINANCIALS & FISCAL
                          _sectionLabel('FINANCIALS & FISCAL'),
                          _navItem('revenue', 'Revenue Hub',
                            Icons.account_balance_wallet_rounded),
                          _navItem('eod', 'Z-Reports / EOD',
                            Icons.receipt_long_rounded,
                            color: AppTheme.iosGreen),
                          _navItem('order_history', 'Order History',
                            Icons.history_rounded),
                          _navItem('advanced_reports', 'Export Reports',
                            Icons.assessment_rounded),

                          _divider(),

                          // ── ANALYTICS
                          _sectionLabel('ANALYTICS'),
                          _navItem('analytics_full', 'Sales Analytics',
                            Icons.insights_rounded),

                          _divider(),

                          // ── TEAM
                          _sectionLabel('TEAM'),
                          _navItem('waiters', 'Staff Management',
                            Icons.badge_rounded),
                          _navItem('shift_history', 'Shift History',
                            Icons.schedule_rounded),

                          _divider(),

                          // ── CONFIGURATION
                          _sectionLabel('CONFIGURATION'),
                          _navItem('menu', 'Menu Items',
                            Icons.fastfood_rounded),
                          _navItem('printers', 'Printer Setup',
                            Icons.print_rounded),
                          _navItem('qr_print', 'QR Codes',
                            Icons.qr_code_rounded),

                          const SizedBox(height: 12),
                        ],
                      ),
                    ),

                    // Settings + Logout
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        children: [
                          _iconButton(
                            icon: Icons.settings_rounded,
                            label: 'Settings',
                            color: AppTheme.primaryColor(context),
                            bgColor: AppTheme.primaryColor(context).withValues(alpha: 0.1),
                            onTap: _openSettings,
                          ),
                          const SizedBox(height: 6),
                          _iconButton(
                            icon: Icons.logout_rounded,
                            label: 'Sign Out',
                            color: AppTheme.errorColor(context),
                            bgColor: AppTheme.errorColor(context).withValues(alpha: 0.08),
                            onTap: () => auth.logout(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),

          // ═══ MAIN CONTENT ═══════════════════════════
          Expanded(
            child: ClipRRect(
              child: _buildCurrentScreen(widget.apiClient, auth, isOwner),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
      child: Text(title,
        style: TextStyle(
          color: AppTheme.textMuted(context).withValues(alpha: 0.6),
          fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Container(
        height: 0.5,
        color: AppTheme.borderColor(context).withValues(alpha: 0.5)),
    );
  }

  Widget _navItem(String route, String label, IconData icon, {Color? color}) {
    final isSelected = _currentRoute == route;
    final primary = color ?? AppTheme.primaryColor(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => setState(() => _currentRoute = route),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
            decoration: BoxDecoration(
              color: isSelected
                ? primary.withValues(alpha: 0.1)
                : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 3, height: isSelected ? 18 : 0,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(2)),
                ),
                Icon(icon,
                  color: isSelected ? primary
                    : AppTheme.textMuted(context).withValues(alpha: 0.6),
                  size: 18),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(label,
                    style: TextStyle(
                      color: isSelected
                        ? AppTheme.textColor(context)
                        : AppTheme.textMuted(context),
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 17),
              const SizedBox(width: 8),
              Text(label,
                style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  // MOBILE NAV
  int _currentMobileTabIndex() {
    if (_currentRoute == 'dashboard') return 0;
    if (_currentRoute == 'table_map') return 1;
    if (_currentRoute == 'revenue' || _currentRoute == 'eod') return 2;
    return 3;
  }

  Widget _buildMobileBottomNav(bool isOwner, AuthProvider auth) {
    return BottomNavigationBar(
      currentIndex: _currentMobileTabIndex(),
      onTap: (i) {
        if (i == 0) setState(() => _currentRoute = 'dashboard');
        else if (i == 1) setState(() => _currentRoute = 'table_map');
        else if (i == 2) setState(() => _currentRoute = 'revenue');
        else _showMobileMenuSheet(isOwner, auth);
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.space_dashboard_rounded), label: 'Dashboard'),
        BottomNavigationBarItem(
          icon: Icon(Icons.table_restaurant_rounded), label: 'Floors'),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet_rounded), label: 'Revenue'),
        BottomNavigationBarItem(
          icon: Icon(Icons.menu_rounded), label: 'More'),
      ],
    );
  }

  void _showMobileMenuSheet(bool isOwner, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderColor(context),
                borderRadius: BorderRadius.circular(2))),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _SectionHeaderLabel('FINANCIALS & FISCAL'),
                  _BottomSheetItem('revenue', 'Revenue Hub',
                    Icons.account_balance_wallet_rounded, ctx),
                  _BottomSheetItem('eod', 'Z-Reports / EOD',
                    Icons.receipt_long_rounded, ctx),
                  _BottomSheetItem('order_history', 'Order History',
                    Icons.history_rounded, ctx),
                  _BottomSheetItem('advanced_reports', 'Export Reports',
                    Icons.assessment_rounded, ctx),
                  _DividerLine(),
                  _SectionHeaderLabel('ANALYTICS'),
                  _BottomSheetItem('analytics_full', 'Sales Analytics',
                    Icons.insights_rounded, ctx),
                  _DividerLine(),
                  _SectionHeaderLabel('TEAM'),
                  _BottomSheetItem('waiters', 'Staff Management',
                    Icons.badge_rounded, ctx),
                  _BottomSheetItem('shift_history', 'Shift History',
                    Icons.schedule_rounded, ctx),
                  _DividerLine(),
                  _SectionHeaderLabel('CONFIGURATION'),
                  _BottomSheetItem('menu', 'Menu Items',
                    Icons.fastfood_rounded, ctx),
                  _BottomSheetItem('printers', 'Printer Setup',
                    Icons.print_rounded, ctx),
                  _BottomSheetItem('qr_print', 'QR Codes',
                    Icons.qr_code_rounded, ctx),
                  _DividerLine(),
                  ListTile(
                    leading: Icon(Icons.settings_rounded,
                      color: AppTheme.primaryColor(context)),
                    title: const Text('Settings',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _openSettings();
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  ),
                  ListTile(
                    leading: Icon(Icons.logout_rounded,
                      color: AppTheme.errorColor(context)),
                    title: Text('Sign Out',
                      style: TextStyle(
                        color: AppTheme.errorColor(context),
                        fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(ctx);
                      auth.logout();
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _SectionHeaderLabel(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
    child: Text(t,
      style: TextStyle(
        color: AppTheme.textMuted(context),
        fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
  );

  Widget _DividerLine() => Divider(
    color: AppTheme.borderColor(context).withValues(alpha: 0.5), height: 16);

  Widget _BottomSheetItem(String route, String label, IconData icon, BuildContext ctx) {
    final isSelected = _currentRoute == route;
    return ListTile(
      leading: Icon(icon,
        color: isSelected
          ? AppTheme.primaryColor(context)
          : AppTheme.textMuted(context)),
      title: Text(label,
        style: TextStyle(
          color: isSelected ? AppTheme.textColor(context) : AppTheme.textMuted(context),
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
      tileColor: isSelected
        ? AppTheme.primaryColor(context).withValues(alpha: 0.08)
        : Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: () {
        setState(() => _currentRoute = route);
        Navigator.pop(ctx);
      },
    );
  }
}

// ==================== MASTER FLOOR PLAN HUB ====================
class _MasterFloorPlanScreen extends StatelessWidget {
  final ApiClient apiClient;
  const _MasterFloorPlanScreen({required this.apiClient});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Master Floor Plan Hub'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'LIVE MONITOR', icon: Icon(Icons.table_restaurant_rounded)),
              Tab(text: 'SETUP TABLES', icon: Icon(Icons.table_bar_rounded)),
              Tab(text: 'SETUP ZONES', icon: Icon(Icons.grid_view_rounded)),
            ],
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

// ==================== SHIFT HISTORY TAB ====================
class _ShiftHistoryTab extends StatelessWidget {
  final ApiClient apiClient;
  const _ShiftHistoryTab({required this.apiClient});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Shift History coming soon',
          style: TextStyle(fontSize: 16))),
    );
  }
}

// ==================== ORDER HISTORY TAB ====================
class _OrderHistoryTab extends StatelessWidget {
  final ApiClient apiClient;
  const _OrderHistoryTab({required this.apiClient});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Order History coming soon',
          style: TextStyle(fontSize: 16))),
    );
  }
}

// ==================== REVENUE TAB ====================
class _RevenueTab extends StatelessWidget {
  final ApiClient apiClient;
  final bool isOwner;
  const _RevenueTab({required this.apiClient, required this.isOwner});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Revenue Hub coming soon',
          style: TextStyle(fontSize: 16))),
    );
  }
}

// ==================== PRINT QR TAB ====================
class _PrintQRTab extends StatelessWidget {
  final ApiClient apiClient;
  const _PrintQRTab({required this.apiClient});
  @override
  Widget build(BuildContext context) {
    return PrintQRScreen(apiClient: apiClient);
  }
}

// ==================== WAITERS TAB ====================

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
  void initState() { super.initState(); _loadWaiters(); }

  Future<void> _loadWaiters() async {
    setState(() => _isLoading = true);
    try {
      final res = await widget.apiClient.get('/admin/waiters');
      setState(() {
        _waiters = List<Map<String, dynamic>>.from(
          (res['data']['waiters'] as List).map(
            (w) => Map<String, dynamic>.from(w as Map)));
        _isLoading = false;
      });
    } catch (e) { setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadWaiters,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _waiters.isEmpty
            ? Center(child: Text('No waiters registered',
                style: TextStyle(color: AppTheme.textMuted(context))))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _waiters.length,
                itemBuilder: (ctx, i) => _buildWaiterCard(_waiters[i]),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddWaiterDialog,
        child: const Icon(Icons.person_add_rounded),
      ),
    );
  }

  Widget _buildWaiterCard(Map<String, dynamic> waiter) {
    final activeShift = waiter['activeShift'] as Map<String, dynamic>?;
    final isOnShift = activeShift != null;
    final isOffTrack = waiter['role'] == 'waiter_offtrack';
    final cash = activeShift?['totalCashCollected']?.toString() ?? '0';
    final zone = activeShift?['zone'] as Map?;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isOnShift
            ? AppTheme.iosGreen
            : AppTheme.textMuted(context).withValues(alpha: 0.3),
          child: Text(
            (waiter['name'] as String? ?? 'W')[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        title: Row(
          children: [
            Text(waiter['name'] as String? ?? '',
              style: const TextStyle(fontWeight: FontWeight.w700)),
            if (isOffTrack) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.iosRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6)),
                child: const Text('OFF-TRACK',
                  style: TextStyle(fontSize: 10, color: AppTheme.iosRed,
                    fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
        subtitle: isOnShift
          ? Text('${zone?['name'] ?? 'Zone'} • Cash: $cash MKD',
              style: TextStyle(color: AppTheme.textMuted(context), fontSize: 12))
          : Text('Offline',
              style: TextStyle(color: AppTheme.textMuted(context), fontSize: 12)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (isOnShift) ...[
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      _statBox('Fiscal',
                        activeShift?['totalFiscal']?.toString() ?? '0',
                        AppTheme.iosGreen),
                      _statBox('Off-Track',
                        activeShift?['totalOffTrack']?.toString() ?? '0',
                        AppTheme.iosRed),
                      _statBox('Total', cash, AppTheme.iosBlue),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _showEditWaiterDialog(waiter),
                      icon: Icon(Icons.edit_rounded,
                        color: AppTheme.iosBlue, size: 20)),
                    IconButton(
                      onPressed: () => _deleteWaiter(waiter['id'] as String),
                      icon: const Icon(Icons.delete_rounded,
                        color: AppTheme.iosRed, size: 20)),
                    if (isOnShift) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showChangeZoneDialog(waiter),
                          icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                          label: const Text('Change Zone'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Container(
      constraints: const BoxConstraints(minWidth: 90),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label,
            style: TextStyle(
              fontSize: 11, color: AppTheme.textMuted(context))),
        ],
      ),
    );
  }

  void _showAddWaiterDialog() {
    final nameC = TextEditingController();
    final usernameC = TextEditingController();
    final passwordC = TextEditingController();
    String role = 'waiter';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Add New Staff Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC,
                decoration: const InputDecoration(labelText: 'Full Name')),
              const SizedBox(height: 12),
              TextField(controller: usernameC,
                decoration: const InputDecoration(labelText: 'Username')),
              const SizedBox(height: 12),
              TextField(controller: passwordC,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'waiter', child: Text('Standard Waiter')),
                  DropdownMenuItem(value: 'waiter_offtrack',
                    child: Text('Waiter (Off-Track)')),
                ],
                onChanged: (v) => ss(() => role = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await widget.apiClient.post('/admin/waiters', body: {
                    'name': nameC.text, 'username': usernameC.text,
                    'password': passwordC.text, 'role': role,
                  });
                  _loadWaiters();
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditWaiterDialog(Map<String, dynamic> waiter) {
    final nameC = TextEditingController(text: waiter['name'] as String? ?? '');
    final usernameC = TextEditingController(
      text: waiter['username'] as String? ?? '');
    final passwordC = TextEditingController();
    String role = waiter['role'] as String? ?? 'waiter';
    if (!['waiter', 'waiter_offtrack'].contains(role)) role = 'waiter';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Edit Staff Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC,
                decoration: const InputDecoration(labelText: 'Full Name')),
              const SizedBox(height: 12),
              TextField(controller: usernameC,
                decoration: const InputDecoration(labelText: 'Username')),
              const SizedBox(height: 12),
              TextField(controller: passwordC,
                decoration: const InputDecoration(
                  labelText: 'New Password (leave blank to keep)'),
                obscureText: true),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'waiter',
                    child: Text('Standard Waiter')),
                  DropdownMenuItem(value: 'waiter_offtrack',
                    child: Text('Waiter (Off-Track)')),
                ],
                onChanged: (v) => ss(() => role = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final body = <String, dynamic>{
                    'name': nameC.text,
                    'username': usernameC.text,
                    'role': role
                  };
                  if (passwordC.text.isNotEmpty)
                    body['password'] = passwordC.text;
                  await widget.apiClient.put(
                    '/admin/waiters/${waiter['id']}', body: body);
                  _loadWaiters();
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteWaiter(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Waiter'),
        content: const Text('Deactivate this waiter account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.iosRed, foregroundColor: Colors.white),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await widget.apiClient.delete('/admin/waiters/$id');
        _loadWaiters();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showChangeZoneDialog(Map<String, dynamic> waiter) async {
    try {
      final res = await widget.apiClient.get('/zones');
      final zones = List<Map<String, dynamic>>.from(
        (res['data']['zones'] as List).map(
          (z) => Map<String, dynamic>.from(z as Map)));
      if (!mounted) return;
      String? selectedZone;
      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, ss) => AlertDialog(
            title: const Text('Change Zone'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: zones.map((z) => RadioListTile<String>(
                title: Text(z['name'] as String),
                value: z['id'] as String,
                groupValue: selectedZone,
                onChanged: (v) => ss(() => selectedZone = v),
              )).toList(),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
              ElevatedButton(
                onPressed: selectedZone == null ? null : () async {
                  Navigator.pop(ctx);
                  try {
                    await widget.apiClient.post(
                      '/admin/waiters/${waiter['id']}/change-zone',
                      body: {'newZoneId': selectedZone});
                    _loadWaiters();
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')));
                  }
                },
                child: const Text('Change'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')));
    }
  }
}

// ==================== ZONES SETUP ====================
class _ZonesSetupTab extends StatefulWidget {
  final ApiClient apiClient;
  const _ZonesSetupTab({required this.apiClient});
  @override
  State<_ZonesSetupTab> createState() => _ZonesSetupTabState();
}

class _ZonesSetupTabState extends State<_ZonesSetupTab> {
  List<Map<String, dynamic>> _zones = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadZones(); }

  Future<void> _loadZones() async {
    setState(() => _isLoading = true);
    try {
      final res = await widget.apiClient.get('/zones');
      setState(() {
        _zones = List<Map<String, dynamic>>.from(
          (res['data']['zones'] as List).map(
            (z) => Map<String, dynamic>.from(z as Map)));
        _isLoading = false;
      });
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadZones,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _zones.length,
              itemBuilder: (ctx, i) {
                final zone = _zones[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Icon(Icons.place_rounded,
                      color: AppTheme.iosOrange),
                    title: Text(zone['name'] as String? ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      'Welcome: ${zone['welcomeMessage'] ?? 'Not set'}',
                      style: TextStyle(
                        color: AppTheme.textMuted(context), fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _showEditZoneDialog(zone),
                          icon: Icon(Icons.edit_rounded,
                            color: AppTheme.iosBlue, size: 18)),
                        IconButton(
                          onPressed: () => _deleteZone(zone['id'] as String),
                          icon: const Icon(Icons.delete_rounded,
                            color: AppTheme.iosRed, size: 18)),
                      ],
                    ),
                  ),
                );
              },
            ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddZoneDialog,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Add Zone'),
      ),
    );
  }

  void _showAddZoneDialog() {
    final nameC = TextEditingController();
    final msgC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Zone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameC,
              decoration: const InputDecoration(labelText: 'Zone Name')),
            const SizedBox(height: 12),
            TextField(controller: msgC,
              decoration: const InputDecoration(
                labelText: 'Welcome Message'), maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.apiClient.post('/zones',
                  body: {'name': nameC.text, 'welcomeMessage': msgC.text});
                _loadZones();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditZoneDialog(Map<String, dynamic> zone) {
    final nameC = TextEditingController(text: zone['name'] as String? ?? '');
    final msgC = TextEditingController(
      text: zone['welcomeMessage'] as String? ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Zone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameC,
              decoration: const InputDecoration(labelText: 'Zone Name')),
            const SizedBox(height: 12),
            TextField(controller: msgC,
              decoration: const InputDecoration(
                labelText: 'Welcome Message'), maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.apiClient.put('/zones/${zone['id']}',
                  body: {'name': nameC.text, 'welcomeMessage': msgC.text});
                _loadZones();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteZone(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Zone'),
        content: const Text('Deactivate this zone? All tables will be hidden.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.iosRed, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await widget.apiClient.delete('/zones/$id');
        _loadZones();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// ==================== TABLES SETUP ====================
class _TablesSetupTab extends StatefulWidget {
  final ApiClient apiClient;
  const _TablesSetupTab({required this.apiClient});
  @override
  State<_TablesSetupTab> createState() => _TablesSetupTabState();
}

class _TablesSetupTabState extends State<_TablesSetupTab> {
  List<Map<String, dynamic>> _zones = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final res = await widget.apiClient.get('/zones');
      setState(() {
        _zones = List<Map<String, dynamic>>.from(
          (res['data']['zones'] as List).map(
            (z) => Map<String, dynamic>.from(z as Map)));
        _isLoading = false;
      });
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _deleteTable(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Table'),
        content: const Text('Remove this physical table?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.iosRed, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await widget.apiClient.delete('/tables/$id');
        _loadData();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showAddTableDialog(String zoneId) {
    final nameC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Table'),
        content: TextField(controller: nameC,
          decoration: const InputDecoration(
            labelText: 'Table Name (e.g. Table 14)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.apiClient.post('/tables',
                  body: {'name': nameC.text, 'zoneId': zoneId});
                _loadData();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _zones.length,
              itemBuilder: (ctx, i) {
                final zone = _zones[i];
                final tables = zone['tables'] as List? ?? [];
                return Card(
                  margin: const EdgeInsets.only(bottom: 20),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.place_rounded,
                                  color: AppTheme.iosOrange),
                                const SizedBox(width: 8),
                                Text(zone['name'] as String? ?? '',
                                  style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            OutlinedButton.icon(
                              onPressed: () =>
                                _showAddTableDialog(zone['id'] as String),
                              icon: const Icon(Icons.add_rounded, size: 14),
                              label: const Text('Add Table'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (tables.isEmpty)
                          Text('No tables in this zone.',
                            style: TextStyle(
                              color: AppTheme.textMuted(context),
                              fontStyle: FontStyle.italic))
                        else
                          Wrap(
                            spacing: 8, runSpacing: 8,
                            children: tables.map<Widget>((t) {
                              final table = Map<String, dynamic>.from(t as Map);
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface2Color(context),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppTheme.borderColor(context).withValues(alpha: 0.6)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.table_restaurant_rounded,
                                      size: 14,
                                      color: AppTheme.textMuted(context)),
                                    const SizedBox(width: 6),
                                    Text(table['name'] as String? ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () =>
                                        _deleteTable(table['id'] as String),
                                      borderRadius: BorderRadius.circular(10),
                                      child: const Padding(
                                        padding: EdgeInsets.all(2),
                                        child: Icon(Icons.close_rounded,
                                          size: 14,
                                          color: AppTheme.iosRed),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }
}

// ==================== MENU MANAGEMENT ====================
class _MenuManagementTab extends StatefulWidget {
  final ApiClient apiClient;
  const _MenuManagementTab({required this.apiClient});
  @override
  State<_MenuManagementTab> createState() => _MenuManagementTabState();
}

class _MenuManagementTabState extends State<_MenuManagementTab> {
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _destinations = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final catRes = await widget.apiClient.get('/categories');
      final destRes = await widget.apiClient.get('/destinations');
      setState(() {
        _categories = List<Map<String, dynamic>>.from(
          (catRes['data']['categories'] as List).map(
            (c) => Map<String, dynamic>.from(c as Map)));
        _destinations = List<Map<String, dynamic>>.from(
          (destRes['data']['destinations'] as List).map(
            (d) => Map<String, dynamic>.from(d as Map)));
        _isLoading = false;
      });
    } catch (e) { setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Order Destinations',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    IconButton(
                      onPressed: _showAddDestinationDialog,
                      icon: Icon(Icons.add_circle_rounded,
                        color: AppTheme.iosBlue)),
                  ],
                ),
                Wrap(
                  spacing: 8, runSpacing: 4,
                  children: _destinations.map((d) => Chip(
                    label: Text(d['name'] as String),
                    deleteIcon: const Icon(Icons.close_rounded, size: 14),
                    onDeleted: () => _deleteDestination(d['id'] as String),
                  )).toList(),
                ),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Categories & Menu Items',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    IconButton(
                      onPressed: _showAddCategoryDialog,
                      icon: Icon(Icons.add_circle_rounded,
                        color: AppTheme.iosBlue)),
                  ],
                ),
                const SizedBox(height: 8),
                ..._categories.map((cat) => _buildCategoryCard(cat)),
              ],
            ),
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    final items = category['items'] as List? ?? [];
    final dest = category['destination'] as Map?;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: Icon(Icons.category_rounded,
          color: AppTheme.iosBlue),
        title: Text(category['name'] as String? ?? '',
          style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('→ ${dest?['name'] ?? 'Unknown'} • ${items.length} items',
          style: TextStyle(color: AppTheme.textMuted(context), fontSize: 12)),
        trailing: IconButton(
          onPressed: () =>
            _showAddMenuItemDialog(category['id'] as String),
          icon: Icon(Icons.add_circle_outline_rounded,
            color: AppTheme.iosOrange, size: 20)),
        children: items.map((item) {
          final m = item as Map;
          return ListTile(
            title: Text(m['name'] as String? ?? '',
              style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(m['description'] as String? ?? '',
              style: TextStyle(
                fontSize: 12, color: AppTheme.textMuted(context))),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${m['price']} MKD',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700, color: AppTheme.iosBlue)),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => _deleteMenuItem(m['id'] as String),
                  icon: const Icon(Icons.delete_outline_rounded,
                    color: AppTheme.iosRed, size: 18)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showAddDestinationDialog() {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Destination'),
        content: TextField(controller: c,
          decoration: const InputDecoration(hintText: 'e.g. Kitchen, Bar')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.apiClient.post('/destinations',
                body: {'name': c.text});
              _loadData();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDestination(String id) async {
    await widget.apiClient.delete('/destinations/$id');
    _loadData();
  }

  Future<void> _deleteMenuItem(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Menu Item'),
        content: const Text('Remove this item from the menu?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.iosRed, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await widget.apiClient.delete('/menu-items/$id');
        _loadData();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showAddCategoryDialog() {
    final nameC = TextEditingController();
    String? destId;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Add Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC,
                decoration: const InputDecoration(labelText: 'Category Name')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Destination'),
                value: destId,
                items: _destinations.map((d) => DropdownMenuItem(
                  value: d['id'] as String,
                  child: Text(d['name'] as String))).toList(),
                onChanged: (v) => ss(() => destId = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
            ElevatedButton(
              onPressed: destId == null ? null : () async {
                Navigator.pop(ctx);
                await widget.apiClient.post('/categories',
                  body: {'name': nameC.text, 'destinationId': destId});
                _loadData();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMenuItemDialog(String categoryId) {
    final nameC = TextEditingController();
    final descC = TextEditingController();
    final priceC = TextEditingController();
    double taxRate = 18.0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Add Menu Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC,
                decoration: const InputDecoration(labelText: 'Item Name')),
              const SizedBox(height: 12),
              TextField(controller: descC,
                decoration: const InputDecoration(labelText: 'Description')),
              const SizedBox(height: 12),
              TextField(controller: priceC,
                decoration: const InputDecoration(labelText: 'Price (MKD)'),
                keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              DropdownButtonFormField<double>(
                decoration: const InputDecoration(labelText: 'Tax Group (ДДВ)'),
                value: taxRate,
                items: const [
                  DropdownMenuItem(value: 18.0,
                    child: Text('Group А (18%)')),
                  DropdownMenuItem(value: 5.0,
                    child: Text('Group Б (5%) - Essentials')),
                ],
                onChanged: (v) { if (v != null) ss(() => taxRate = v); },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await widget.apiClient.post('/menu-items', body: {
                    'name': nameC.text,
                    'description': descC.text,
                    'price': double.tryParse(priceC.text) ?? 0,
                    'categoryId': categoryId,
                    'taxRate': taxRate,
                  });
                  _loadData();
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')));
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

// ==================== QR PRINT HELPER ====================
Future<void> _openPrintableQR(
  BuildContext context, String zoneName,
  List<Map<String, dynamic>> tables,
) async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context ctx) => [
        pw.Header(level: 0,
          child: pw.Text('QR Codes — $zoneName',
            style: pw.TextStyle(fontSize: 24,
              fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 16),
        pw.Wrap(
          spacing: 20, runSpacing: 20,
          children: tables.map((table) => pw.Container(
            width: 200, height: 250,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 1),
              borderRadius: const pw.BorderRadius.all(
                pw.Radius.circular(12))),
            padding: const pw.EdgeInsets.all(16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(table['name'] as String? ?? 'Table',
                  style: pw.TextStyle(fontSize: 18,
                    fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 12),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: table['qrToken'] as String? ??
                        table['id'] as String? ?? '',
                  width: 150, height: 150),
                pw.SizedBox(height: 12),
                pw.Text('Scan to Order',
                  style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
          )).toList(),
        ),
      ],
    ),
  );
  await Printing.layoutPdf(
    onLayout: (PdfPageFormat fmt) async => pdf.save());
}
