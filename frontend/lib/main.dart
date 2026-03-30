import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'services/api_client.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/admin/admin_login_screen.dart';
import 'screens/waiter/waiter_home_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/customer/customer_scan_screen.dart';
import 'screens/developer/developer_home_screen.dart';
import 'screens/admin/ops_kitchen_bar_screen.dart';
import 'services/background_service.dart';
import 'services/notification_service.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  await EasyLocalization.ensureInitialized();

  // Initialize native notifications on ALL platforms (Android, iOS, Windows, etc.)
  if (!kIsWeb) {
    try {
      await NotificationService.instance.initialize();
    } catch (e) {
      debugPrint('Notification service init failed: $e');
    }
  }

  // Background service only works on Android/iOS
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await initializeBackgroundService();
    } catch (e) {
      debugPrint('Background service init failed: $e');
    }
  }

  final apiClient = ApiClient();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('mk'), Locale('sq')], // Note: sq is standard for Albanian
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider(apiClient)),
        ],
        child: RestaurantApp(apiClient: apiClient),
      ),
    ),
  );
}

class RestaurantApp extends StatelessWidget {
  final ApiClient apiClient;
  const RestaurantApp({super.key, required this.apiClient});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      title: 'Restaurant Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const AppEntryScreen(),
        '/login': (context) => const LoginScreen(),
        '/waiter': (context) => WaiterHomeScreen(apiClient: apiClient),
        '/admin': (context) => AdminHomeScreen(apiClient: apiClient),
        '/developer': (context) => DeveloperHomeScreen(apiClient: apiClient),
        '/customer': (context) => const CustomerScanScreen(),
        '/admin-login': (context) => const AdminLoginScreen(),
      },
    );
  }
}

class AppEntryScreen extends StatefulWidget {
  const AppEntryScreen({super.key});

  @override
  State<AppEntryScreen> createState() => _AppEntryScreenState();
}

class _AppEntryScreenState extends State<AppEntryScreen> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final auth = context.read<AuthProvider>();
    await auth.init();
    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: AppTheme.premiumGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.restaurant, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text(
                'Restaurant Manager',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              const CircularProgressIndicator(color: AppTheme.primary),
            ],
          ),
        ),
      );
    }

    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isAuthenticated) {
          // Route based on role
          switch (auth.userRole) {
            case 'owner':
            case 'admin':
              return AdminHomeScreen(apiClient: ApiClient()..setToken(auth.token));
            case 'waiter':
            case 'waiter_offtrack':
              return WaiterHomeScreen(apiClient: ApiClient()..setToken(auth.token));
            case 'kitchen':
            case 'bar':
              return OpsKitchenBarScreen(apiClient: ApiClient()..setToken(auth.token));
            case 'developer':
              return DeveloperHomeScreen(apiClient: ApiClient()..setToken(auth.token));
            default:
              return const LoginScreen();
          }
        }
        return const LoginScreen();
      },
    );
  }
}
