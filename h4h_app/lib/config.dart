/// Central configuration for the app.
/// When your WiFi/IP changes, update ONLY [backendIp] here.
class AppConfig {
  // ─── Change this one value when your local IP changes ───────────────────────
  static const String backendIp = '10.22.139.200';
  // ────────────────────────────────────────────────────────────────────────────

  /// FastAPI backend  (port 8000)
  static const String apiBaseUrl = 'http://$backendIp:8000';

  /// Node/Chat backend  (port 3000)
  static const String chatBaseUrl = 'http://$backendIp:3000';

  /// RL telemetry endpoint (same FastAPI backend)
  static const String rlTelemetryUrl = '$apiBaseUrl/api/rl/feedback';

  /// Save-order endpoint (same FastAPI backend)
  static const String ordersUrl = '$apiBaseUrl/api/orders';
}
