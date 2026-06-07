/// Central configuration for the app.
/// When your WiFi/IP changes, update ONLY [backendIp] here.
class AppConfig {
  // ─── Change this one value when your local IP changes ───────────────────────
  static const String backendIp = '10.22.224.14';
  // ────────────────────────────────────────────────────────────────────────────

  /// FastAPI backend  (port 8000)
  static const String apiBaseUrl = 'http://$backendIp:8000';

  /// Node/Chat backend  (port 3000)
  static const String chatBaseUrl = 'http://$backendIp:3000';

  /// RL telemetry endpoint (same FastAPI backend)
  static const String rlTelemetryUrl = '$apiBaseUrl/api/rl/feedback';

  /// Save-order endpoint (same FastAPI backend)
  static const String ordersUrl = '$apiBaseUrl/api/orders';

  /// Auto-order agent endpoint (LangChain + Gemini, same FastAPI backend)
  static const String autoOrderUrl = '$apiBaseUrl/api/pedido-automatico';

  /// "How useful was the agent" feedback endpoint (same FastAPI backend)
  static const String agentFeedbackUrl = '$apiBaseUrl/api/agent-feedback';
  /// Goals (Metas) endpoints
  static const String goalsUrl = '$apiBaseUrl/api/goals';
  static const String goalsSuggestionsUrl = '$apiBaseUrl/api/goals/suggestions';
}
