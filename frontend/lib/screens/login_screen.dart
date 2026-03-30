import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import 'kitchen_bar_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isMobile = false;
  String? _selectedWaiterName;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final width = MediaQuery.of(context).size.width;
      setState(() {
        _isMobile = width < 600;
      });
      if (_isMobile) {
        context.read<AuthProvider>().loadWaiterList();
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final auth = context.read<AuthProvider>();
    final username = _isMobile ? (_selectedWaiterName ?? '') : _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill in all fields'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final success = await auth.login(username, password);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Login failed'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.background,
              AppTheme.surfaceDark,
              AppTheme.surface,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Container(
                width: isWide ? 440 : double.infinity,
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      blurRadius: 60,
                      offset: const Offset(0, 20),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: AppTheme.premiumGradient,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.asset(
                          'assets/images/restaurant_logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.restaurant_rounded,
                            size: 42,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Restaurant Manager',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isMobile ? 'Select your name and enter password' : 'Enter your credentials to sign in',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Mobile: Waiter dropdown
                    if (_isMobile) ...[
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          if (auth.waiterList.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: CircularProgressIndicator(color: AppTheme.primary),
                            );
                          }
                          return Container(
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                hint: const Text('Select Waiter', style: TextStyle(color: AppTheme.textSecondary)),
                                value: _selectedWaiterName,
                                dropdownColor: AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(14),
                                items: auth.waiterList.map((w) {
                                  return DropdownMenuItem<String>(
                                    value: w['username'] as String,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            gradient: AppTheme.premiumGradient,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Center(
                                            child: Text(
                                              (w['name'] as String)[0].toUpperCase(),
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(w['name'] as String, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (v) => setState(() => _selectedWaiterName = v),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Desktop: Username field
                    if (!_isMobile) ...[
                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          hintText: 'Username',
                          prefixIcon: Icon(Icons.person_outline_rounded, color: AppTheme.textSecondary),
                        ),
                        style: const TextStyle(color: AppTheme.textPrimary),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Password field
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.textSecondary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: AppTheme.textSecondary,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      style: const TextStyle(color: AppTheme.textPrimary),
                      onSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: 28),

                    // Login button
                    Consumer<AuthProvider>(
                      builder: (context, auth, _) {
                        return Container(
                          width: double.infinity,
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: AppTheme.premiumGradient,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: auth.isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: auth.isLoading
                                ? const SizedBox(
                                    width: 24, height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Divider
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.06))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('or', style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5), fontSize: 13)),
                        ),
                        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.06))),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Customer QR button
                    TextButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/customer'),
                      icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.accent, size: 20),
                      label: const Text(
                        'I\'m a customer (Scan QR)',
                        style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Kitchen / Bar
                    TextButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KitchenBarLoginScreen())),
                      icon: Icon(Icons.kitchen_rounded, color: AppTheme.textSecondary.withValues(alpha: 0.7), size: 20),
                      label: Text(
                        'Kitchen & Bar Displays →',
                        style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.7), fontWeight: FontWeight.w500),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Admin/Owner login
                    TextButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/admin-login'),
                      icon: Icon(Icons.admin_panel_settings_outlined, color: AppTheme.textSecondary.withValues(alpha: 0.7), size: 20),
                      label: Text(
                        'Admin / Owner Login →',
                        style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.7), fontWeight: FontWeight.w500),
                      ),
                    ),
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
