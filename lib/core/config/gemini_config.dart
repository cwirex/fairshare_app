/// Configuration for Google Gemini API
abstract class GeminiConfig {
  /// The API key for Google Gemini
  /// TODO: Replace with secure loading mechanism (skip for development)
  static const String apiKey = 'AIzaSyA9g1_j8DQmvw_EjuyU3UFrU2H2LJ9kqck';

  /// The model to use for category suggestions
  /// Options: 'gemini-pro', 'gemini-2.0-flash', etc.
  static const String model = 'gemini-2.0-flash';

  /// Whether Gemini is enabled
  /// Set to false to disable AI suggestions (useful for offline)
  static const bool enabled = true;

  /// Timeout for API requests (in seconds)
  static const int timeoutSeconds = 10;

  /// Whether Gemini is available (API key configured and enabled)
  static bool get isAvailable => apiKey.isNotEmpty && enabled;
}
