import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/app_theme.dart';
import '../../services/api_client.dart';

class CustomerMenuScreen extends StatefulWidget {
  final Map<String, dynamic> tableData;
  final ApiClient api;

  const CustomerMenuScreen({super.key, required this.tableData, required this.api});

  @override
  State<CustomerMenuScreen> createState() => _CustomerMenuScreenState();
}

class _CustomerMenuScreenState extends State<CustomerMenuScreen> {
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  final Map<String, int> _cart = {}; // menuItemId -> quantity
  final Map<String, String> _itemNotes = {}; // menuItemId -> note
  final Map<String, Map<String, dynamic>> _itemDetails = {};
  int _selectedCategoryIndex = 0;
  bool _isOrdering = false;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  String get _sessionId => widget.tableData['session']?['id'] as String? ?? '';
  String get _tableName => widget.tableData['table']?['name'] as String? ?? 'Table';
  String get _welcomeMessage => widget.tableData['welcomeMessage'] as String? ?? '';
  List get _existingOrders => widget.tableData['existingOrders'] as List? ?? [];

  Future<void> _loadMenu() async {
    try {
      final res = await widget.api.get('/customer/menu');
      setState(() {
        _categories = List<Map<String, dynamic>>.from(
          (res['data']['categories'] as List).map((c) => Map<String, dynamic>.from(c as Map)),
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  int get _totalCartItems => _cart.values.fold(0, (a, b) => a + b);

  double get _totalCartPrice {
    double total = 0;
    _cart.forEach((id, qty) {
      final item = _itemDetails[id];
      if (item != null) {
        total += (double.tryParse(item['price'].toString()) ?? 0) * qty;
      }
    });
    return total;
  }

  Future<void> _placeOrder() async {
    if (_cart.isEmpty) return;

    setState(() => _isOrdering = true);
    try {
      final items = _cart.entries.map((e) => {
        'menuItemId': e.key,
        'quantity': e.value,
        'notes': _itemNotes[e.key] ?? '',
      }).toList();

      await widget.api.post('/customer/order', body: {
        'sessionId': _sessionId,
        'items': items,
      });

      if (mounted) {
        setState(() {
          _cart.clear();
          _itemNotes.clear();
          _isOrdering = false;
        });
        _showSuccessDialog();
      }
    } catch (e) {
      setState(() => _isOrdering = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error'.tr(args: [e.toString()])), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 32),
            const SizedBox(width: 12),
            Text('order_placed'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('order_placed_desc'.tr(), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: Text('got_it'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showItemNoteDialog(String itemId, String itemName) {
    final controller = TextEditingController(text: _itemNotes[itemId] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Note for $itemName', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'e.g., no cheese, extra spicy...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _itemNotes.remove(itemId));
              Navigator.pop(ctx);
            },
            child: Text('clear'.tr(), style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              setState(() {
                if (text.isNotEmpty) {
                  _itemNotes[itemId] = text;
                } else {
                  _itemNotes.remove(itemId);
                }
              });
              Navigator.pop(ctx);
            },
            child: Text('save_note'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _callWaiter() async {
    try {
      await widget.api.post('/customer/call-waiter', body: {'sessionId': _sessionId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('waiter_called'.tr()), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _requestBill() async {
    try {
      await widget.api.post('/customer/request-bill', body: {'sessionId': _sessionId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('bill_requested'.tr()), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _requestWater() async {
    try {
      await widget.api.post('/customer/request-water', body: {'sessionId': _sessionId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('water_requested'.tr()), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Widget _buildAlreadyOrdered() {
    if (_existingOrders.isEmpty) return const SizedBox();

    final Map<String, int> aggregated = {};
    for (final order in _existingOrders) {
      if (order['status'] != 'paid' && order['status'] != 'cancelled') {
        final items = order['items'] as List? ?? [];
        for (final it in items) {
          final name = it['menuItem']?['name'] as String? ?? 'Item';
          final qty = it['quantity'] as int? ?? 1;
          aggregated[name] = (aggregated[name] ?? 0) + qty;
        }
      }
    }

    if (aggregated.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_rounded, color: AppTheme.primaryLight, size: 20),
              const SizedBox(width: 8),
              Text('already_ordered'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppTheme.primaryLight)),
            ],
          ),
          const SizedBox(height: 16),
          ...aggregated.entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(e.key, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(8)),
                  child: Text('x${e.value}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.accent)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.background, AppTheme.surfaceDark],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : Column(
                  children: [
                    // Premium Glassmorphic Header
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceDark.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.5),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 30, offset: const Offset(0, 10)),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset('assets/images/restaurant_logo.png', width: 36, height: 36, fit: BoxFit.cover),
                              ),
                              const SizedBox(height: 8),
                              Text('welcome_to'.tr(), style: const TextStyle(color: AppTheme.primaryLight, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                              const SizedBox(height: 2),
                              Text(_tableName.toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: Colors.white)),
                            ],
                          ),
                          Row(
                            children: [
                              _actionIcon(Icons.water_drop_rounded, 'Water', _requestWater),
                              const SizedBox(width: 8),
                              _actionIcon(Icons.room_service_rounded, 'Call Waiter', _callWaiter),
                              const SizedBox(width: 8),
                              _actionIcon(Icons.receipt_long_rounded, 'Bill', _requestBill),
                            ],
                          ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ).animate().fade(duration: 600.ms).slideY(begin: -0.2),

                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 100), // Space for cart
                        children: [
                          if (_welcomeMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              child: Text(_welcomeMessage, style: const TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic, fontSize: 15)),
                            ),
                          
                          _buildAlreadyOrdered(),
                          
                          const SizedBox(height: 24),
                          // Horizontal Categories
                          SizedBox(
                            height: 48,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _categories.length,
                              itemBuilder: (ctx, i) {
                                final isSelected = i == _selectedCategoryIndex;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: GestureDetector(
                                    onTap: () => setState(() => _selectedCategoryIndex = i),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppTheme.primary : AppTheme.surfaceLight.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(color: isSelected ? AppTheme.primaryLight : Colors.white.withValues(alpha: 0.05)),
                                        boxShadow: isSelected ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))] : [],
                                      ),
                                      child: Center(
                                        child: Text(
                                          (_categories[i]['name'] as String? ?? '').toUpperCase(),
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : AppTheme.textSecondary,
                                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                            letterSpacing: 1.1,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ).animate().fade(
                                  delay: (40 * i).ms, duration: 400.ms
                                ).slideX(begin: 0.1);
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          _categories.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Center(child: Text('no_menu_available'.tr(), style: const TextStyle(color: AppTheme.textSecondary))),
                                )
                              : _buildMenuList(),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
      // Floating Cart Bar
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _cart.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 30, offset: const Offset(0, 10)),
                        BoxShadow(color: AppTheme.primary.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, -5)),
                      ],
                    ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$_totalCartItems ${'items_in_cart'.tr()}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const SizedBox(height: 2),
                      Text('${_totalCartPrice.toStringAsFixed(0)} MKD',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.accent)),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: _isOrdering ? null : _placeOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                      shadowColor: AppTheme.primary.withValues(alpha: 0.5),
                    ),
                    child: _isOrdering
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('order_now'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ).animate().fade().slideY(begin: 0.2, duration: 400.ms, curve: Curves.easeOutCubic)
    : null,
  );
  }

  Widget _actionIcon(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Icon(icon, size: 22, color: AppTheme.textPrimary),
        ),
      ),
    );
  }

  Widget _buildMenuList() {
    if (_selectedCategoryIndex >= _categories.length) return const SizedBox();
    final items = _categories[_selectedCategoryIndex]['items'] as List? ?? [];
    if (items.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text('no_items_category'.tr(), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
      ));
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = Map<String, dynamic>.from(items[i] as Map);
        final id = item['id'] as String;
        final qty = _cart[id] ?? 0;
        final note = _itemNotes[id];
        _itemDetails[id] = item;
        
        final isActive = qty > 0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primary.withValues(alpha: 0.05) : AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isActive ? AppTheme.primary.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.03),
              width: isActive ? 1.5 : 1,
            ),
            boxShadow: isActive 
                ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8))]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((item['name'] as String? ?? ''), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                    if (item['description'] != null && (item['description'] as String).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 8),
                        child: Text(item['description'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4)),
                      ),
                    const SizedBox(height: 8),
                    Text('${item['price']} MKD', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.accent)),
                    
                    if (isActive) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _showItemNoteDialog(id, item['name'] as String? ?? ''),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: note?.isNotEmpty == true ? AppTheme.info.withValues(alpha: 0.1) : AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: note?.isNotEmpty == true ? AppTheme.info.withValues(alpha: 0.3) : Colors.transparent),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_note_rounded, size: 16, color: note?.isNotEmpty == true ? AppTheme.info : AppTheme.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                note?.isNotEmpty == true ? 'Note: $note' : 'Add Special Request',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: note?.isNotEmpty == true ? AppTheme.info : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              const SizedBox(width: 16),
              
              // Quantity Controls
              qty == 0
                  ? InkWell(
                      onTap: () => setState(() => _cart[id] = 1),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: const Icon(Icons.add_rounded, color: AppTheme.textPrimary, size: 24),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => setState(() => _cart[id] = qty + 1),
                            icon: const Icon(Icons.add_rounded, size: 20, color: AppTheme.textPrimary),
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                          ),
                          IconButton(
                            onPressed: () => setState(() {
                              if (qty <= 1) { _cart.remove(id); _itemNotes.remove(id); } else { _cart[id] = qty - 1; }
                            }),
                            icon: const Icon(Icons.remove_rounded, size: 20, color: AppTheme.textSecondary),
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          ),
                        ],
                      ),
                    ),
            ],
          ),
        ).animate().fade(
          duration: 400.ms, 
          delay: (50 * i).ms
        ).slideX(
          begin: 0.05, 
          duration: 400.ms, 
          delay: (50 * i).ms
        );
      },
    );
  }
}
