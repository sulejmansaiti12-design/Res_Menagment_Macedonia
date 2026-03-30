import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../config/app_theme.dart';
import '../../services/api_client.dart';
import '../../providers/auth_provider.dart';
import 'analytics_screen.dart';
import 'advanced_reports_screen.dart';
import 'ops_kitchen_bar_screen.dart';
import 'ops_requests_screen.dart';
import 'ops_table_map_screen.dart';
import 'printer_setup_screen.dart';
import 'end_of_day_screen.dart';
import 'qr_print_screen.dart';
import 'tabs/dashboard_tab.dart'; // NEW

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
      // Command Center
      case 'dashboard': return DashboardTab(apiClient: api, auth: auth);
      case 'overview': return DashboardTab(apiClient: api, auth: auth); // Fallback
      
      // Operations
      case 'table_map': return _MasterFloorPlanScreen(apiClient: api);
      case 'requests': return OpsRequestsScreen(apiClient: api);
      
      // Team & Staff
      case 'waiters': return _WaitersTab(apiClient: api);
      case 'shift_history': return _ShiftHistoryTab(apiClient: api);
      
      // Financials
      case 'order_history': return _OrderHistoryTab(apiClient: api);
      case 'revenue': return _RevenueTab(apiClient: api, isOwner: isOwner);
      case 'analytics_full': return AnalyticsScreen(apiClient: api);
      case 'eod': return EndOfDayScreen(apiClient: api, isOwner: isOwner);
      case 'advanced_reports': return AdvancedReportsScreen(apiClient: api);
      
      // Configuration
      case 'menu': return _MenuManagementTab(apiClient: api);
      case 'printers': return PrinterSetupScreen(apiClient: api);
      case 'qr_print': return _PrintQRTab(apiClient: api);
      
      default: return DashboardTab(apiClient: api, auth: auth);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isOwner = auth.userRole == 'owner';

    final isDesktop = MediaQuery.of(context).size.width >= 800;

    if (!isDesktop) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: _currentRoute == 'dashboard' ? null : AppBar(
          backgroundColor: AppTheme.surfaceDark,
          title: Row(
            children: [
              const Icon(Icons.restaurant, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(isOwner ? 'Owner Dashboard' : 'Admin Dashboard', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: isOwner ? AppTheme.warning : AppTheme.info,
                  child: Text(auth.userName.isNotEmpty ? auth.userName[0].toUpperCase() : 'A', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
        body: _buildCurrentScreen(widget.apiClient, auth, isOwner),
        bottomNavigationBar: _buildMobileBottomNav(isOwner, auth),
      );
    }

    final sidebarWidth = 280.0;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          // ═══════════════════════════════════════════════
          // ═══════════════════════════════════════════════
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: sidebarWidth,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark.withValues(alpha: 0.7),
                  border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                ),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // ── Brand Header ──────────────────────────
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primary.withValues(alpha: 0.12), AppTheme.primary.withValues(alpha: 0.04)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisAlignment: isDesktop ? MainAxisAlignment.start : MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primary, AppTheme.success],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 3))],
                        ),
                        child: const Icon(Icons.restaurant, color: Colors.white, size: 20),
                      ),
                      if (isDesktop) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('POS Manager', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                              const SizedBox(height: 2),
                              Text(
                                isOwner ? 'Owner Portal' : 'Admin Portal',
                                style: TextStyle(color: AppTheme.primaryLight.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // ── User Profile Card ─────────────────────
                if (isDesktop)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isOwner
                                  ? [AppTheme.warning, AppTheme.warning.withValues(alpha: 0.8)]
                                  : [AppTheme.info, AppTheme.info.withValues(alpha: 0.8)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              auth.userName.isNotEmpty ? auth.userName[0].toUpperCase() : 'A',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(auth.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13), overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isOwner ? AppTheme.warning.withValues(alpha: 0.15) : AppTheme.info.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isOwner ? 'OWNER' : 'ADMIN',
                                  style: TextStyle(color: isOwner ? AppTheme.warning : AppTheme.info, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isDesktop) const SizedBox(height: 20),
                // ── Navigation ────────────────────────────
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    children: [
                      if (isOwner) ...[
                        _buildSectionLabel('OWNER DASHBOARD', isDesktop),
                        _buildNavItem('dashboard', 'Dashboard', Icons.space_dashboard_rounded, isDesktop),
                        _buildNavItem('analytics_full', 'Sales Analytics', Icons.insights_rounded, isDesktop),
                        _buildNavItem('waiters', 'Staff Analytics', Icons.badge_rounded, isDesktop),
                        _buildNavItem('revenue', 'Revenue Hub', Icons.account_balance_wallet_rounded, isDesktop),
                        _buildNavItem('advanced_reports', 'Export Reports', Icons.assessment_rounded, isDesktop),
                      ] else ...[
                        _buildSectionLabel('DASHBOARD', isDesktop),
                        _buildNavItem('dashboard', 'Dashboard', Icons.space_dashboard_rounded, isDesktop),
                        _buildNavItem('table_map', 'Master Floor Plan', Icons.table_restaurant_rounded, isDesktop),
                        _buildNavItem('requests', 'Notifications', Icons.notifications_active_rounded, isDesktop),
                        _buildDivider(isDesktop),
                        _buildSectionLabel('ANALYTICS & FINANCIALS', isDesktop),
                        _buildNavItem('revenue', 'Revenue & Payments', Icons.account_balance_wallet_rounded, isDesktop),
                        _buildNavItem('analytics_full', 'Advanced Analytics', Icons.insights_rounded, isDesktop),
                        _buildNavItem('eod', 'Z-Reports', Icons.summarize_rounded, isDesktop),
                        _buildNavItem('advanced_reports', 'Export Reports', Icons.assessment_rounded, isDesktop),
                        _buildDivider(isDesktop),
                        _buildSectionLabel('TEAM', isDesktop),
                        _buildNavItem('waiters', 'Staff Management', Icons.badge_rounded, isDesktop),
                        _buildNavItem('shift_history', 'Shift History', Icons.history_rounded, isDesktop),
                        _buildDivider(isDesktop),
                        _buildSectionLabel('CONFIGURATION', isDesktop),
                        _buildNavItem('menu', 'Menu Items', Icons.fastfood_rounded, isDesktop),
                        _buildNavItem('printers', 'Printer Setup', Icons.print_rounded, isDesktop),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                // ── Logout ────────────────────────────────
                Container(
                  margin: const EdgeInsets.all(12),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => auth.logout(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.error.withValues(alpha: 0.12)),
                        ),
                        child: Row(
                          mainAxisAlignment: isDesktop ? MainAxisAlignment.start : MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout_rounded, color: AppTheme.error.withValues(alpha: 0.8), size: 18),
                            if (isDesktop) ...[
                              const SizedBox(width: 10),
                              Text('Sign Out', style: TextStyle(color: AppTheme.error.withValues(alpha: 0.8), fontWeight: FontWeight.w700, fontSize: 13)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
        ),
          // ═══════════════════════════════════════════════
          // MAIN CONTENT AREA
          // ═══════════════════════════════════════════════
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
                border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.03))),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
                child: _buildCurrentScreen(widget.apiClient, auth, isOwner),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _currentMobileTabIndex() {
    if (_currentRoute == 'dashboard' || _currentRoute == 'overview') return 0;
    if (_currentRoute == 'table_map') return 1;
    if (_currentRoute == 'revenue') return 2;
    return 3;
  }

  Widget _buildMobileBottomNav(bool isOwner, AuthProvider auth) {
    return BottomNavigationBar(
      backgroundColor: AppTheme.surfaceDark,
      selectedItemColor: AppTheme.primaryLight,
      unselectedItemColor: Colors.white54,
      type: BottomNavigationBarType.fixed,
      currentIndex: _currentMobileTabIndex(),
      onTap: (index) {
        if (index == 0) setState(() => _currentRoute = 'dashboard');
        else if (index == 1) setState(() => _currentRoute = 'table_map');
        else if (index == 2) setState(() => _currentRoute = 'revenue');
        else if (index == 3) _showMobileMenuSheet(isOwner, auth);
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.space_dashboard_rounded), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.table_restaurant_rounded), label: 'Floors'),
        BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: 'Revenue'),
        BottomNavigationBarItem(icon: Icon(Icons.menu_rounded), label: 'More'),
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
          color: AppTheme.surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(margin: const EdgeInsets.only(top: 12, bottom: 8), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (isOwner) ...[
                    _buildSectionLabel('OWNER DASHBOARD', true),
                    _buildBottomNavItem('analytics_full', 'Sales Analytics', Icons.insights_rounded, ctx),
                    _buildBottomNavItem('waiters', 'Staff Analytics', Icons.badge_rounded, ctx),
                    _buildBottomNavItem('revenue', 'Revenue Hub', Icons.account_balance_wallet_rounded, ctx),
                    _buildBottomNavItem('advanced_reports', 'Export Reports', Icons.assessment_rounded, ctx),
                  ] else ...[
                    _buildSectionLabel('DASHBOARD', true),
                    _buildBottomNavItem('requests', 'Notifications', Icons.notifications_active_rounded, ctx),
                    _buildDivider(true),
                    _buildSectionLabel('ANALYTICS & FINANCIALS', true),
                    _buildBottomNavItem('revenue', 'Revenue & Payments', Icons.account_balance_wallet_rounded, ctx),
                    _buildBottomNavItem('analytics_full', 'Advanced Analytics', Icons.insights_rounded, ctx),
                    _buildBottomNavItem('eod', 'Z-Reports', Icons.summarize_rounded, ctx),
                    _buildBottomNavItem('advanced_reports', 'Export Reports', Icons.assessment_rounded, ctx),
                    _buildDivider(true),
                    _buildSectionLabel('TEAM', true),
                    _buildBottomNavItem('waiters', 'Staff Management', Icons.badge_rounded, ctx),
                    _buildBottomNavItem('shift_history', 'Shift History', Icons.history_rounded, ctx),
                    _buildDivider(true),
                    _buildSectionLabel('CONFIGURATION', true),
                    _buildBottomNavItem('menu', 'Menu Items', Icons.fastfood_rounded, ctx),
                    _buildBottomNavItem('printers', 'Printer Setup', Icons.print_rounded, ctx),
                  ],
                  
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        auth.logout();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error.withValues(alpha: 0.2), foregroundColor: AppTheme.error, padding: const EdgeInsets.symmetric(vertical: 16)),
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign Out'),
                    ),
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

  Widget _buildBottomNavItem(String route, String label, IconData icon, BuildContext ctx) {
    final isSelected = _currentRoute == route;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? AppTheme.primaryLight : Colors.white54),
        title: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        tileColor: isSelected ? AppTheme.primary.withValues(alpha: 0.1) : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () {
          setState(() => _currentRoute = route);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Widget _buildSectionLabel(String title, bool isDesktop) {
    if (!isDesktop) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.only(left: 14, bottom: 6, top: 4),
      child: Text(
        title,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.22), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.8),
      ),
    );
  }

  Widget _buildDivider(bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Container(height: 1, color: Colors.white.withValues(alpha: 0.04)),
    );
  }

  Widget _buildNavItem(String route, String label, IconData icon, bool isDesktop) {
    final isSelected = _currentRoute == route;
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _currentRoute = route),
          borderRadius: BorderRadius.circular(10),
          hoverColor: Colors.white.withValues(alpha: 0.04),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: isDesktop ? 14 : 0),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primary.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: isDesktop ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                if (isDesktop)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 3,
                    height: isSelected ? 20 : 0,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                Icon(icon, color: isSelected ? AppTheme.primaryLight : Colors.white.withValues(alpha: 0.35), size: 20),
                if (isDesktop) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.55),
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
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
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primaryLight,
            unselectedLabelColor: Colors.white54,
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(), // Nests scroll cleanly
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
  void initState() {
    super.initState();
    _loadWaiters();
  }

  Future<void> _loadWaiters() async {
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
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadWaiters,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : _waiters.isEmpty
                ? const Center(child: Text('No waiters registered', style: TextStyle(color: AppTheme.textSecondary)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _waiters.length,
                    itemBuilder: (ctx, i) => _buildWaiterCard(_waiters[i]),
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddWaiterDialog,
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildWaiterCard(Map<String, dynamic> waiter) {
    final activeShift = waiter['activeShift'] as Map<String, dynamic>?;
    final isOnShift = activeShift != null;
    final isOffTrackUser = waiter['role'] == 'waiter_offtrack';
    final cash = activeShift?['totalCashCollected']?.toString() ?? '0';
    final zone = activeShift?['zone'] as Map?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isOnShift ? AppTheme.success : AppTheme.textSecondary,
          child: Text(
            (waiter['name'] as String? ?? 'W')[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Text(waiter['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (isOffTrackUser) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('OFF-TRACK ACCOUNT', style: TextStyle(fontSize: 10, color: AppTheme.error, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        subtitle: isOnShift
            ? Text('${zone?['name'] ?? 'Unknown Zone'} • Cash: $cash MKD',
                style: const TextStyle(color: AppTheme.textSecondary))
            : const Text('Offline', style: TextStyle(color: AppTheme.textSecondary)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (isOnShift) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _statBox('Fiscal', activeShift?['totalFiscal']?.toString() ?? '0', AppTheme.success),
                      _statBox('Off-Track', activeShift?['totalOffTrack']?.toString() ?? '0', AppTheme.error),
                      _statBox('Total', cash, AppTheme.accent),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _showEditWaiterDialog(waiter),
                      icon: const Icon(Icons.edit, color: AppTheme.info),
                    ),
                    IconButton(
                      onPressed: () => _deleteWaiter(waiter['id'] as String),
                      icon: const Icon(Icons.delete, color: AppTheme.error),
                    ),
                  ],
                ),
                if (isOnShift) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showChangeZoneDialog(waiter),
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('Change Zone'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Container(
      constraints: const BoxConstraints(minWidth: 100),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
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
              TextField(controller: nameC, decoration: const InputDecoration(hintText: 'Full Name')),
              const SizedBox(height: 12),
              TextField(controller: usernameC, decoration: const InputDecoration(hintText: 'Username')),
              const SizedBox(height: 12),
              TextField(controller: passwordC, decoration: const InputDecoration(hintText: 'Password'), obscureText: true),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(labelText: 'Role Type'),
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
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await widget.apiClient.post('/admin/waiters', body: {
                    'name': nameC.text,
                    'username': usernameC.text,
                    'password': passwordC.text,
                    'role': role,
                  });
                  _loadWaiters();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
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

  void _showEditWaiterDialog(Map<String, dynamic> waiter) {
    final nameC = TextEditingController(text: waiter['name'] as String? ?? '');
    final usernameC = TextEditingController(text: waiter['username'] as String? ?? '');
    final passwordC = TextEditingController();
    String role = waiter['role'] as String? ?? 'waiter';

    if (role != 'waiter' && role != 'waiter_offtrack') role = 'waiter';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Edit Staff Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC, decoration: const InputDecoration(hintText: 'Full Name')),
              const SizedBox(height: 12),
              TextField(controller: usernameC, decoration: const InputDecoration(hintText: 'Username')),
              const SizedBox(height: 12),
              TextField(controller: passwordC, decoration: const InputDecoration(hintText: 'New Password (leave empty to keep)'), obscureText: true),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(labelText: 'Role Type'),
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
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final body = <String, dynamic>{
                    'name': nameC.text, 
                    'username': usernameC.text,
                    'role': role
                  };
                  if (passwordC.text.isNotEmpty) body['password'] = passwordC.text;
                  await widget.apiClient.put('/admin/waiters/${waiter['id']}', body: body);
                  _loadWaiters();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
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

  Future<void> _deleteWaiter(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Waiter'),
        content: const Text('Are you sure you want to deactivate this waiter?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await widget.apiClient.delete('/admin/waiters/$id');
        _loadWaiters();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _showChangeZoneDialog(Map<String, dynamic> waiter) async {
    try {
      final res = await widget.apiClient.get('/zones');
      final zones = List<Map<String, dynamic>>.from(
        (res['data']['zones'] as List).map((z) => Map<String, dynamic>.from(z as Map)),
      );

      if (!mounted) return;
      String? selectedZone;
      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, ss) => AlertDialog(
            title: const Text('Change Zone'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: zones.map((z) {
                return RadioListTile<String>(
                  title: Text(z['name'] as String),
                  value: z['id'] as String,
                  groupValue: selectedZone,
                  onChanged: (v) => ss(() => selectedZone = v),
                );
              }).toList(),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: selectedZone == null
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        try {
                          final changeRes = await widget.apiClient.post('/admin/waiters/${waiter['id']}/change-zone', body: {'newZoneId': selectedZone});
                          if (changeRes['success'] == false) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(changeRes['error']?['message'] ?? 'Error'), backgroundColor: AppTheme.warning),
                            );
                          } else {
                            _loadWaiters();
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
                          );
                        }
                      },
                child: const Text('Change'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    }
  }
}

// ==================== ZONES TAB ====================

// ==================== ZONES SETUP TAB ====================

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
  void initState() {
    super.initState();
    _loadZones();
  }

  Future<void> _loadZones() async {
    setState(() => _isLoading = true);
    try {
      final res = await widget.apiClient.get('/zones');
      setState(() {
        _zones = List<Map<String, dynamic>>.from(
          (res['data']['zones'] as List).map((z) => Map<String, dynamic>.from(z as Map)),
        );
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadZones,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _zones.length,
                itemBuilder: (ctx, i) {
                  final zone = _zones[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const Icon(Icons.place, color: AppTheme.accent),
                      title: Text(zone['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Welcome: ${zone['welcomeMessage'] ?? 'Not set'}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(onPressed: () => _showEditZoneDialog(zone), icon: const Icon(Icons.edit, color: AppTheme.info, size: 20)),
                          IconButton(onPressed: () => _deleteZone(zone['id'] as String), icon: const Icon(Icons.delete, color: AppTheme.error, size: 20)),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddZoneDialog,
        icon: const Icon(Icons.add_location),
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
            TextField(controller: nameC, decoration: const InputDecoration(hintText: 'Zone Name')),
            const SizedBox(height: 12),
            TextField(controller: msgC, decoration: const InputDecoration(hintText: 'Welcome Message'), maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.apiClient.post('/zones', body: {'name': nameC.text, 'welcomeMessage': msgC.text});
                _loadZones();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
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
    final msgC = TextEditingController(text: zone['welcomeMessage'] as String? ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Zone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameC, decoration: const InputDecoration(hintText: 'Zone Name')),
            const SizedBox(height: 12),
            TextField(controller: msgC, decoration: const InputDecoration(hintText: 'Welcome Message'), maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.apiClient.put('/zones/${zone['id']}', body: {'name': nameC.text, 'welcomeMessage': msgC.text});
                _loadZones();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteZone(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Zone'),
        content: const Text('Deactivate this zone? All tables inside will also be hidden.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await widget.apiClient.delete('/zones/$id');
        _loadZones();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    }
  }
}

// ==================== TABLES SETUP TAB ====================

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
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final res = await widget.apiClient.get('/zones');
      setState(() {
        _zones = List<Map<String, dynamic>>.from(
          (res['data']['zones'] as List).map((z) => Map<String, dynamic>.from(z as Map)),
        );
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteTable(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Table'),
        content: const Text('Remove this physical table?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await widget.apiClient.delete('/tables/$id');
        _loadData();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  void _showAddTableDialog(String zoneId) {
    final nameC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Table'),
        content: TextField(controller: nameC, decoration: const InputDecoration(hintText: 'Table Name (e.g. Table 14)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.apiClient.post('/tables', body: {'name': nameC.text, 'zoneId': zoneId});
                _loadData();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
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
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _zones.length,
                itemBuilder: (ctx, i) {
                  final zone = _zones[i];
                  final tables = zone['tables'] as List? ?? [];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 24),
                    color: AppTheme.surfaceLight.withValues(alpha: 0.3),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.place, color: AppTheme.accent),
                                  const SizedBox(width: 8),
                                  Text(zone['name'] as String? ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _showAddTableDialog(zone['id'] as String),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add Table'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                  side: BorderSide(color: AppTheme.primaryLight.withValues(alpha: 0.5)),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          if (tables.isEmpty)
                            const Text('No tables in this zone.', style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic))
                          else
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: tables.map<Widget>((t) {
                                final table = Map<String, dynamic>.from(t as Map);
                                return Container(
                                  padding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.table_restaurant, size: 16, color: AppTheme.textSecondary),
                                      const SizedBox(width: 8),
                                      Text(table['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 4),
                                      InkWell(
                                        onTap: () => _deleteTable(table['id'] as String),
                                        borderRadius: BorderRadius.circular(16),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4.0),
                                          child: Icon(Icons.close, size: 16, color: AppTheme.error),
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

Future<void> _openPrintableQR(BuildContext context, String zoneName, List<Map<String, dynamic>> tables) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return [
          pw.Header(level: 0, child: pw.Text('QR Codes — $zoneName', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 16),
          pw.Wrap(
            spacing: 20,
            runSpacing: 20,
            children: tables.map((table) {
              return pw.Container(
                width: 200,
                height: 250,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 1),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                ),
                padding: const pw.EdgeInsets.all(16),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(table['name'] as String? ?? 'Table', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 12),
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: table['qrToken'] as String? ?? table['id'] as String? ?? '',
                      width: 150,
                      height: 150,
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text('Scan to Order', style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
              );
            }).toList(),
          ),
        ];
      },
    ),
  );

  await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
}

// ==================== MENU MANAGEMENT TAB ====================

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
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final catRes = await widget.apiClient.get('/categories');
      final destRes = await widget.apiClient.get('/destinations');
      setState(() {
        _categories = List<Map<String, dynamic>>.from(
          (catRes['data']['categories'] as List).map((c) => Map<String, dynamic>.from(c as Map)),
        );
        _destinations = List<Map<String, dynamic>>.from(
          (destRes['data']['destinations'] as List).map((d) => Map<String, dynamic>.from(d as Map)),
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Destinations section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Order Destinations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(onPressed: _showAddDestinationDialog, icon: const Icon(Icons.add, color: AppTheme.accent)),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: _destinations.map((d) {
                      return Chip(
                        label: Text(d['name'] as String),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => _deleteDestination(d['id'] as String),
                      );
                    }).toList(),
                  ),
                  const Divider(height: 32),

                  // Categories section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Categories & Menu Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(onPressed: _showAddCategoryDialog, icon: const Icon(Icons.add, color: AppTheme.accent)),
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
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: const Icon(Icons.category, color: AppTheme.primaryLight),
        title: Text(category['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('→ ${dest?['name'] ?? 'Unknown'} • ${items.length} items', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _showAddMenuItemDialog(category['id'] as String),
              icon: const Icon(Icons.add_circle, color: AppTheme.accent, size: 20),
            ),
          ],
        ),
        children: [
          ...items.map((item) {
            final menuItem = item as Map;
            return ListTile(
              title: Text(menuItem['name'] as String? ?? ''),
              subtitle: Text(menuItem['description'] as String? ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${menuItem['price']} MKD', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent)),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _deleteMenuItem(menuItem['id'] as String),
                    icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                    tooltip: 'Delete item',
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showAddDestinationDialog() {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Destination'),
        content: TextField(controller: c, decoration: const InputDecoration(hintText: 'e.g. Kitchen, Bar')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.apiClient.post('/destinations', body: {'name': c.text});
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Menu Item'),
        content: const Text('Remove this item from the menu?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await widget.apiClient.delete('/menu-items/$id');
        _loadData();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
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
              TextField(controller: nameC, decoration: const InputDecoration(hintText: 'Category Name')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(hintText: 'Destination'),
                value: destId,
                items: _destinations.map((d) => DropdownMenuItem(value: d['id'] as String, child: Text(d['name'] as String))).toList(),
                onChanged: (v) => ss(() => destId = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: destId == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await widget.apiClient.post('/categories', body: {'name': nameC.text, 'destinationId': destId});
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
    double _taxRate = 18.0; // Default to Group A
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Add Menu Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC, decoration: const InputDecoration(hintText: 'Item Name')),
              const SizedBox(height: 12),
              TextField(controller: descC, decoration: const InputDecoration(hintText: 'Description')),
              const SizedBox(height: 12),
              TextField(controller: priceC, decoration: const InputDecoration(hintText: 'Price (MKD)'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              DropdownButtonFormField<double>(
                decoration: const InputDecoration(hintText: 'Tax Group (ДДВ)'),
                value: _taxRate,
                items: const [
                  DropdownMenuItem(value: 18.0, child: Text('Group А (18%)')),
                  DropdownMenuItem(value: 5.0, child: Text('Group Б (5%) - Essentials')),
                ],
                onChanged: (v) {
                  if (v != null) ss(() => _taxRate = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await widget.apiClient.post('/menu-items', body: {
                  'name': nameC.text,
                  'description': descC.text,
                  'price': double.tryParse(priceC.text) ?? 0,
                  'categoryId': categoryId,
                  'taxRate': _taxRate,
                });
                _loadData();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== SHIFT HISTORY TAB ====================

class _ShiftHistoryTab extends StatefulWidget {
  final ApiClient apiClient;
  const _ShiftHistoryTab({required this.apiClient});

  @override
  State<_ShiftHistoryTab> createState() => _ShiftHistoryTabState();
}

class _ShiftHistoryTabState extends State<_ShiftHistoryTab> {
  List<Map<String, dynamic>> _shifts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  Future<void> _loadShifts() async {
    setState(() => _isLoading = true);
    try {
      final res = await widget.apiClient.get('/shifts/history');
      if (!mounted) return;
      setState(() {
        _shifts = List<Map<String, dynamic>>.from(
          (res['data']['shifts'] as List).map((s) => Map<String, dynamic>.from(s as Map)),
        );
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _printShiftReceipt(Map<String, dynamic> shift) async {
    final waiterName = shift['waiter']?['name'] ?? 'Unknown';
    final start = shift['startTime'] ?? '';
    final end = shift['endTime'] ?? '';
    final totalCash = shift['totalCashCollected'] ?? '0';
    final fiscalCash = shift['totalFiscal'] ?? '0';
    final offTrackCash = shift['totalOffTrack'] ?? '0';

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Center(child: pw.Text('SHIFT RECEIPT', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 10),
              pw.Text('Waiter: $waiterName'),
              pw.Text('Start: ${_formatDate(start)}'),
              pw.Text('End: ${_formatDate(end)}'),
              pw.Divider(),
              pw.SizedBox(height: 5),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Fiscal:'), pw.Text('$fiscalCash MKD')]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Off-Track:'), pw.Text('$offTrackCash MKD')]),
              pw.Divider(),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('TOTAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('$totalCash MKD', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ]),
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Text('--- END OF SHIFT ---')),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Shift_Receipt_$waiterName.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — matches Order History style
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppTheme.premiumGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.schedule_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Shift History', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    SizedBox(height: 4),
                    Text('Complete log of all waiter shifts', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loadShifts,
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryLight),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _shifts.isEmpty
                    ? const Center(child: Text('No shift history yet', style: TextStyle(color: AppTheme.textSecondary)))
                    : RefreshIndicator(
                        onRefresh: _loadShifts,
                        child: ListView.builder(
                          itemCount: _shifts.length,
                          itemBuilder: (ctx, i) => _buildShiftCard(_shifts[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftCard(Map<String, dynamic> shift) {
    final waiter = shift['waiter'] as Map?;
    final zone = shift['zone'] as Map?;
    final isActive = shift['endTime'] == null;
    final total = shift['totalCashCollected']?.toString() ?? '0';
    final fiscal = shift['totalFiscal']?.toString() ?? '0';
    final offTrack = shift['totalOffTrack']?.toString() ?? '0';
    final waiterName = waiter?['name'] as String? ?? 'Unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isActive ? AppTheme.success : AppTheme.textSecondary,
          child: Text(
            waiterName[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(waiterName, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.success.withValues(alpha: 0.15)
                    : AppTheme.textSecondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isActive ? 'ACTIVE' : 'COMPLETED',
                style: TextStyle(
                  fontSize: 10,
                  color: isActive ? AppTheme.success : AppTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${zone?['name'] ?? 'Unknown Zone'} • ${_formatDate(shift['startTime'] ?? '')}',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stat boxes — same pattern as Waiters tab
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _shiftStat('Fiscal', '$fiscal MKD', AppTheme.success),
                    _shiftStat('Off-Track', '$offTrack MKD', AppTheme.error),
                    _shiftStat('Total', '$total MKD', AppTheme.accent),
                  ],
                ),
                const SizedBox(height: 12),

                // Time details
                Row(
                  children: [
                    const Icon(Icons.login_rounded, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'Start: ${_formatDate(shift['startTime'] ?? '')}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      isActive ? Icons.timelapse_rounded : Icons.logout_rounded,
                      size: 14,
                      color: isActive ? AppTheme.success : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isActive ? 'Currently active' : 'End: ${_formatDate(shift['endTime'] ?? '')}',
                      style: TextStyle(
                        color: isActive ? AppTheme.success : AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

                // Print action — only for completed shifts
                if (!isActive) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _printShiftReceipt(shift),
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Print Shift Receipt'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shiftStat(String label, String value, Color color) {
    return Container(
      constraints: const BoxConstraints(minWidth: 100),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final d = DateTime.parse(dateStr).toLocal();
      return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}

// ==================== REVENUE TAB ====================

class _RevenueTab extends StatefulWidget {
  final ApiClient apiClient;
  final bool isOwner;
  const _RevenueTab({required this.apiClient, required this.isOwner});

  @override
  State<_RevenueTab> createState() => _RevenueTabState();
}

class _RevenueTabState extends State<_RevenueTab> {
  Map<String, dynamic>? _revenue;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRevenue();
  }

  Future<void> _loadRevenue() async {
    setState(() => _isLoading = true);
    try {
      final res = await widget.apiClient.get('/admin/revenue');
      setState(() {
        _revenue = res['data'] as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));

    final total = _revenue?['totalRevenue']?.toString() ?? '0';
    final fiscal = _revenue?['fiscalRevenue']?.toString() ?? '0';
    final offTrack = _revenue?['offTrackRevenue']?.toString() ?? '0';
    final byWaiter = (_revenue?['byWaiter'] as List?)?.map((w) => Map<String, dynamic>.from(w as Map)).toList() ?? [];

    return RefreshIndicator(
      onRefresh: _loadRevenue,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Today's Revenue", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _revCard('Total', '$total MKD', AppTheme.accent, Icons.monetization_on),
              _revCard('Fiscal', '$fiscal MKD', AppTheme.success, Icons.receipt),
              _revCard('Off-Track', '$offTrack MKD', AppTheme.error, Icons.receipt_long),
            ],
          ),
          const SizedBox(height: 24),
          const Text('By Waiter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...byWaiter.map((w) {
            final waiterInfo = w['waiter'] as Map?;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryLight,
                  child: Text((waiterInfo?['name'] as String? ?? 'W')[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                ),
                title: Text(waiterInfo?['name'] as String? ?? 'Unknown'),
                subtitle: Text('${w['count']} payments • Fiscal: ${w['fiscal']} • Off: ${w['offTrack']}', style: const TextStyle(fontSize: 12)),
                trailing: Text('${w['total']} MKD', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent)),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _revCard(String label, String value, Color color, IconData icon) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

// ==================== ACTIVE SHIFTS TAB ====================

// _ActiveShiftsTab removed - now merged into _ShiftHistoryTab

// ==================== PRINT & QR TAB ====================

class _PrintQRTab extends StatefulWidget {
  final ApiClient apiClient;
  const _PrintQRTab({required this.apiClient});

  @override
  State<_PrintQRTab> createState() => _PrintQRTabState();
}

class _PrintQRTabState extends State<_PrintQRTab> {
  List<Map<String, dynamic>> _waiters = [];
  List<Map<String, dynamic>> _zones = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final wRes = await widget.apiClient.get('/admin/waiters');
      final zRes = await widget.apiClient.get('/zones');
      setState(() {
        _waiters = List<Map<String, dynamic>>.from(
          (wRes['data']['waiters'] as List).map((w) => Map<String, dynamic>.from(w as Map)),
        );
        _zones = List<Map<String, dynamic>>.from(
          (zRes['data']['zones'] as List).map((z) => Map<String, dynamic>.from(z as Map)),
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _selectedDate = d);
  }

  Future<void> _printWaiterReport(String? waiterId, String waiterName) async {
    try {
      final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
      String url = '/admin/reports/print?date=$dateStr';
      if (waiterId != null) url += '&waiterId=$waiterId';

      final res = await widget.apiClient.get(url);
      final shifts = List<Map<String, dynamic>>.from(
        ((res['data']?['shifts'] ?? []) as List).map((s) => Map<String, dynamic>.from(s as Map)),
      );

      if (!mounted) return;
      await _generateAndPrintReport(
        title: waiterId != null ? 'Report: $waiterName' : 'All Waiters Report',
        date: dateStr,
        shifts: shifts,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));

    final dateStr = '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Date Picker
        const Text('📊 Print Reports', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.calendar_today, color: AppTheme.accent),
            title: const Text('Report Date'),
            subtitle: Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent)),
            trailing: TextButton(onPressed: _pickDate, child: const Text('Change')),
          ),
        ),
        const SizedBox(height: 12),

        // Print all waiters
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => _printWaiterReport(null, 'All'),
            icon: const Icon(Icons.print),
            label: const Text('Print ALL Waiters Report'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryLight),
          ),
        ),
        const SizedBox(height: 16),

        // Print individual waiter
        const Text('Print Individual Waiter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ..._waiters.map((w) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryLight,
                child: Text((w['name'] as String? ?? 'W')[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
              ),
              title: Text(w['name'] as String? ?? ''),
              subtitle: Text(w['username'] as String? ?? '', style: const TextStyle(fontSize: 12)),
              trailing: IconButton(
                icon: const Icon(Icons.print, color: AppTheme.accent),
                onPressed: () => _printWaiterReport(w['id'] as String, w['name'] as String? ?? ''),
              ),
            ),
          );
        }),

        const Divider(height: 32),

        // QR Code Printing
        const Text('🏷️ Print Table QR Codes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Select a zone to print QR codes for all its tables. Customers scan these to place orders.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const SizedBox(height: 12),
        ..._zones.map((z) {
          final tables = z['tables'] as List? ?? [];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.place, color: AppTheme.accent),
              title: Text(z['name'] as String? ?? ''),
              subtitle: Text('${tables.length} tables'),
              trailing: ElevatedButton.icon(
                onPressed: () => _openPrintableQR(
                  context,
                  z['name'] as String? ?? 'Zone',
                  tables.map((t) => Map<String, dynamic>.from(t as Map)).toList(),
                ),
                icon: const Icon(Icons.qr_code, size: 18),
                label: const Text('Print QR'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, padding: const EdgeInsets.symmetric(horizontal: 12)),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ==================== PRINTABLE REPORT SCREEN ====================

Future<void> _generateAndPrintReport({required String title, required String date, required List<Map<String, dynamic>> shifts}) async {
  final pdf = pw.Document();

  double grandFiscal = 0, grandOffTrack = 0, grandTotal = 0;
  int totalPayments = 0;
  for (final shift in shifts) {
    final payments = shift['payments'] as List? ?? [];
    for (final p in payments) {
      final payment = p as Map;
      final amount = double.tryParse(payment['amount']?.toString() ?? '0') ?? 0;
      grandTotal += amount;
      if (payment['isFiscal'] == true) {
        grandFiscal += amount;
      } else {
        grandOffTrack += amount;
      }
      totalPayments++;
    }
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return [
          pw.Header(level: 0, child: pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
          pw.Text('Date: $date', style: const pw.TextStyle(fontSize: 14)),
          pw.SizedBox(height: 20),
          
          pw.TableHelper.fromTextArray(
            headers: ['Total Revenue', 'Fiscal Revenue', 'Off-Track Revenue', 'Total Payments'],
            data: [
              ['${grandTotal.toStringAsFixed(0)} MKD', '${grandFiscal.toStringAsFixed(0)} MKD', '${grandOffTrack.toStringAsFixed(0)} MKD', '$totalPayments'],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.center,
          ),
          pw.SizedBox(height: 30),

          ...shifts.map((shift) {
            final waiter = shift['waiter'] as Map?;
            final zone = shift['zone'] as Map?;
            final payments = shift['payments'] as List? ?? [];
            final startTime = shift['startTime'] as String? ?? '';
            final endTime = shift['endTime'] as String?;

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Waiter: ${waiter?['name'] ?? 'Unknown'} (Zone: ${zone?['name'] ?? 'N/A'})', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text('Shift Time: $startTime — ${endTime ?? 'Active'}', style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 10),
                if (payments.isEmpty)
                  pw.Text('No payments in this shift.', style: const pw.TextStyle(fontSize: 12))
                else
                  pw.TableHelper.fromTextArray(
                    headers: ['Table', 'Type', 'Amount', 'Items'],
                    data: payments.map((p) {
                      final payment = p as Map;
                      final order = payment['order'] as Map?;
                      final session = order?['tableSession'] as Map?;
                      final table = session?['table'] as Map?;
                      final items = order?['items'] as List? ?? [];
                      final isFiscal = payment['isFiscal'] == true;

                      final itemsStr = items.map((it) {
                        final mi = (it as Map)['menuItem'] as Map?;
                        return '${it['quantity']}x ${mi?['name'] ?? 'Item'}';
                      }).join(', ');

                      return [
                        table?['name']?.toString() ?? 'Table',
                        isFiscal ? 'FISCAL' : 'OFF-TRACK',
                        '${payment['amount']} MKD',
                        itemsStr,
                      ];
                    }).toList(),
                    cellStyle: const pw.TextStyle(fontSize: 10),
                    headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 10),
              ],
            );
          }).toList(),
        ];
      },
    ),
  );

  await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
}

// ==================== ANALYTICS QUICK TAB ====================

class _AnalyticsQuickTab extends StatefulWidget {
  final ApiClient apiClient;
  const _AnalyticsQuickTab({required this.apiClient});

  @override
  State<_AnalyticsQuickTab> createState() => _AnalyticsQuickTabState();
}

class _AnalyticsQuickTabState extends State<_AnalyticsQuickTab> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Analytics & Insights', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('View detailed performance data and export reports', style: TextStyle(color: AppTheme.textSecondary)),
        const SizedBox(height: 24),

        _buildQuickActionCard(
          title: 'Staff & Sales Analytics',
          subtitle: 'Waiter performance, sales trends, hourly breakdowns, top items',
          icon: Icons.analytics,
          color: AppTheme.accent,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AnalyticsScreen(apiClient: widget.apiClient)),
          ),
        ),
        const SizedBox(height: 12),

        _buildQuickActionCard(
          title: 'Export Reports',
          subtitle: 'Download payments, shifts, and orders reports as CSV',
          icon: Icons.download,
          color: AppTheme.success,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AdvancedReportsScreen(apiClient: widget.apiClient)),
          ),
        ),
        const SizedBox(height: 24),

        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Available Analytics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                _FeatureItem(icon: Icons.people, text: 'Staff Performance Rankings'),
                _FeatureItem(icon: Icons.trending_up, text: 'Sales Trends & Hourly Breakdowns'),
                _FeatureItem(icon: Icons.restaurant_menu, text: 'Top-Selling Menu Items'),
                _FeatureItem(icon: Icons.place, text: 'Zone Revenue Comparisons'),
                _FeatureItem(icon: Icons.table_restaurant, text: 'Table Turnover Metrics'),
                _FeatureItem(icon: Icons.download, text: 'CSV Export for All Reports'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryLight),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

// ==================== ORDER HISTORY TAB ====================

class _OrderHistoryTab extends StatefulWidget {
  final ApiClient apiClient;
  const _OrderHistoryTab({required this.apiClient});

  @override
  State<_OrderHistoryTab> createState() => _OrderHistoryTabState();
}

class _OrderHistoryTabState extends State<_OrderHistoryTab> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final res = await widget.apiClient.get('/admin/history?limit=200');
      setState(() {
        _history = List<Map<String, dynamic>>.from(
          (res['data']['history'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _stornoPayment(String paymentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Storno', style: TextStyle(color: AppTheme.error)),
        content: const Text('Are you sure you want to refund/storno this payment? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Refund'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await widget.apiClient.post('/payments/storno', body: {'paymentId': paymentId, 'reason': 'Admin requested via dashboard'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment successfully refunded / marked storno'), backgroundColor: AppTheme.success));
        _loadHistory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.accent]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order History', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    SizedBox(height: 4),
                    Text('Chronological log of all completed orders', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loadHistory,
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryLight),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _history.isEmpty
                    ? const Center(child: Text('No order history yet', style: TextStyle(color: AppTheme.textSecondary)))
                    : Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(AppTheme.surfaceLight.withValues(alpha: 0.5)),
                              dataRowMaxHeight: 72,
                              columnSpacing: 20,
                              columns: const [
                                DataColumn(label: Text('TIME', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.2, color: AppTheme.textSecondary))),
                                DataColumn(label: Text('ZONE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.2, color: AppTheme.textSecondary))),
                                DataColumn(label: Text('TABLE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.2, color: AppTheme.textSecondary))),
                                DataColumn(label: Text('WAITER', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.2, color: AppTheme.textSecondary))),
                                DataColumn(label: Text('ITEMS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.2, color: AppTheme.textSecondary))),
                                DataColumn(label: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.2, color: AppTheme.textSecondary)), numeric: true),
                                DataColumn(label: Text('TYPE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.2, color: AppTheme.textSecondary))),
                                DataColumn(label: Text('ACTION', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.2, color: AppTheme.textSecondary))),
                              ],
                              rows: _history.map((p) {
                                final order = p['order'] as Map<String, dynamic>? ?? {};
                                final session = order['tableSession'] as Map<String, dynamic>? ?? {};
                                final table = session['table'] as Map<String, dynamic>? ?? {};
                                final zone = table['zone'] as Map<String, dynamic>? ?? {};
                                final waiter = p['waiter'] as Map<String, dynamic>? ?? {};
                                final items = (order['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                                final isFiscal = p['isFiscal'] == true;
                                final paidAt = DateTime.tryParse(p['paidAt']?.toString() ?? p['createdAt']?.toString() ?? '');
                                final timeStr = paidAt != null
                                    ? '${paidAt.day.toString().padLeft(2, '0')}/${paidAt.month.toString().padLeft(2, '0')} ${paidAt.hour.toString().padLeft(2, '0')}:${paidAt.minute.toString().padLeft(2, '0')}'
                                    : '—';
                                final itemNames = items.map((i) {
                                  final mi = i['menuItem'] as Map<String, dynamic>? ?? {};
                                  final qty = i['quantity'] ?? 1;
                                  return '${mi['name'] ?? 'Item'} x$qty';
                                }).join(', ');
                                final total = double.tryParse(p['amount']?.toString() ?? '0') ?? 0;

                                return DataRow(cells: [
                                  DataCell(Text(timeStr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                                  DataCell(Text(zone['name']?.toString() ?? '—', style: const TextStyle(fontSize: 13))),
                                  DataCell(Text(table['name']?.toString() ?? '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                                  DataCell(Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.2),
                                        child: Text(
                                          (waiter['name']?.toString() ?? '?')[0].toUpperCase(),
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryLight),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(waiter['name']?.toString() ?? '—', style: const TextStyle(fontSize: 13)),
                                    ],
                                  )),
                                  DataCell(SizedBox(
                                    width: 180,
                                    child: Text(itemNames, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  )),
                                  DataCell(Text('${total.toStringAsFixed(0)} MKD', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.success))),
                                  DataCell(Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isFiscal ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.error.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isFiscal ? 'FISCAL' : 'OFF-TRACK',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isFiscal ? AppTheme.success : AppTheme.error, letterSpacing: 0.5),
                                    ),
                                  )),
                                  DataCell(
                                    OutlinedButton.icon(
                                      onPressed: () => _stornoPayment(p['id'].toString()),
                                      icon: const Icon(Icons.undo_rounded, size: 14, color: AppTheme.error),
                                      label: const Text('Storno', style: TextStyle(color: AppTheme.error, fontSize: 12)),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                        side: BorderSide(color: AppTheme.error.withValues(alpha: 0.5)),
                                      ),
                                    ),
                                  ),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
