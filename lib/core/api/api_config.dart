import 'package:flutter/foundation.dart';

String cookPilotApiBaseUrl() {
  const configuredApiBaseUrl = String.fromEnvironment('COOKPILOT_API_BASE_URL');
  if (configuredApiBaseUrl.isNotEmpty) {
    return configuredApiBaseUrl;
  }

  return defaultApiBaseUrlFor(isWeb: kIsWeb, platform: defaultTargetPlatform);
}

String defaultApiBaseUrlFor({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  if (isWeb) {
    return 'http://localhost:8080';
  }
  if (platform == TargetPlatform.android) {
    return 'http://10.0.2.2:8080';
  }
  return 'http://localhost:8080';
}
