class AppConfig {
  // Update this IP whenever your machine's local IP address changes
  static const String backendIp = '10.22.224.14';
  
  static const String apiBaseUrl = 'http://$backendIp:8000';
  static const String chatBaseUrl = 'http://$backendIp:3000';
}
