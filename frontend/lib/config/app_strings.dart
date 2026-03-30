class AppStrings {
  // Common
  static const String appName = 'Restaurant Management';
  static const String loading = 'Loading...';
  static const String cancel = 'Cancel';
  static const String close = 'Close';
  static const String error = 'Error';
  static const String save = 'Save';
  static const String success = 'Success';

  // Auth / Login
  static const String loginTitle = 'Welcome Back';
  static const String usernameHint = 'Username';
  static const String passwordHint = 'Password';
  static const String loginBtn = 'Log In';
  static const String invalidCredentials = 'Invalid credentials';

  // Waiter Module
  static const String waiterShiftStart = 'Start Shift';
  static const String selectZone = 'Select Zone';
  static const String activeOrders = 'ACTIVE ORDERS';
  static const String noActiveOrders = 'No Active Orders';
  static const String tables = 'TABLES';
  static const String notifications = 'NOTIFICATIONS';
  static const String checkout = 'PAY TABLE';
  static const String acceptOrder = 'Accept Order';
  static const String declineOrder = 'Decline Order';

  // Customer Module
  static const String theMenu = 'The Menu';
  static const String callWaiter = 'Call Waiter';
  static const String requestBill = 'Request Bill';
  static const String orderSent = 'Order sent to preparation!';
  static const String yourCart = 'Your Cart';

  // Admin Module
  static const String adminDashboard = 'Dashboard';
  static const String adminAnalytics = 'Analytics';
  static const String printQR = 'Print QR Codes';
  static const String printReports = 'Print Reports';
  static const String manageStaff = 'Manage Staff';

  // Developer Module
  static const String devConsole = 'Developer Console';
  static const String databaseSettings = 'Database Settings';
  static const String fiscalApi = 'Fiscal API Setup';
  
  // Future Usage for Localization:
  // 1. Install `easy_localization` or `flutter_localizations`
  // 2. Replace static const String references with localized keys (e.g., 'loginTitle'.tr())
  // 3. Create JSON maps for en.json, mk.json, sq.json matching these keys.
}
