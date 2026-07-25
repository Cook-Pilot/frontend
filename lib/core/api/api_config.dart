const defaultApiBaseUrl = 'http://10.0.2.2:8080';

String cookPilotApiBaseUrl() {
  return const String.fromEnvironment(
    'COOKPILOT_API_BASE_URL',
    defaultValue: defaultApiBaseUrl,
  );
}
