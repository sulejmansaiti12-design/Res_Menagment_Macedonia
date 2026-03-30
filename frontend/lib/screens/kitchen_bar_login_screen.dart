import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';

class KitchenBarLoginScreen extends StatefulWidget {
  const KitchenBarLoginScreen({super.key});

  @override
  State<KitchenBarLoginScreen> createState() => _KitchenBarLoginScreenState();
}

class _KitchenBarLoginScreenState extends State<KitchenBarLoginScreen> {
  String _pin = '';
  bool _isLoading = false;

  void _onKeypadPressed(String val) {
    if (_pin.length < 4) {
      setState(() {
        _pin += val;
      });
      if (_pin.length == 4) {
        _submitPin();
      }
    }
  }

  void _onBackspacePressed() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  Future<void> _submitPin() async {
    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();

    bool success = await auth.login('kitchen', _pin);
    if (!success) {
      success = await auth.login('bar', _pin);
    }

    if (success) {
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      if (!mounted) return;
      setState(() {
        _pin = '';
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Invalid PIN. Access Denied.'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppTheme.premiumGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.restaurant_rounded, size: 48, color: Colors.white),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Enter Staff PIN',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Kitchen & Bar personnel only',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 48),

                // PIN Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isFilled = index < _pin.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      width: isFilled ? 22 : 18,
                      height: isFilled ? 22 : 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled ? AppTheme.primary : Colors.transparent,
                        border: Border.all(
                          color: isFilled ? AppTheme.primary : AppTheme.textSecondary.withValues(alpha: 0.3),
                          width: 2,
                        ),
                        boxShadow: isFilled
                            ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.4), blurRadius: 12)]
                            : [],
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 56),

                // Numpad
                if (_isLoading)
                  const CircularProgressIndicator(color: AppTheme.primary)
                else
                  _buildNumpad(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [_buildKeypadButton('1'), _buildKeypadButton('2'), _buildKeypadButton('3')],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [_buildKeypadButton('4'), _buildKeypadButton('5'), _buildKeypadButton('6')],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [_buildKeypadButton('7'), _buildKeypadButton('8'), _buildKeypadButton('9')],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 76),
            _buildKeypadButton('0'),
            SizedBox(
              width: 76,
              height: 76,
              child: TextButton(
                onPressed: _onBackspacePressed,
                style: TextButton.styleFrom(shape: const CircleBorder()),
                child: const Icon(Icons.backspace_rounded, size: 26, color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String number) {
    return SizedBox(
      width: 76,
      height: 76,
      child: ElevatedButton(
        onPressed: () => _onKeypadPressed(number),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.surfaceLight,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Text(
          number,
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w400),
        ),
      ),
    );
  }
}
