class AppConfig {
  // Change this to your server IP/URL
  // For Android emulator: 10.0.2.2
  // For physical device: your computer's local IP (e.g., 192.168.1.100)
  // For web: localhost
  //defaultValue: 'http://localhost:3000/api',
  // https://excusingly-overfrequent-coretta.ngrok-free.dev/api
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://excusingly-overfrequent-coretta.ngrok-free.dev/api',
  );

  static const String appName = 'Restaurant Manager';
  static const Duration httpTimeout = Duration(seconds: 30);
}
