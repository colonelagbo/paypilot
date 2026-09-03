// SPDX-License-Identifier: Apache-2.0

/// Environment URLs and authentication constants for the BMONI Embedded API.
class BmoniUrls {
  const BmoniUrls._();

  /// Production base URL.
  static const String production = 'https://embedded.bmoni.com';

  /// Development / Sandbox base URL.
  static const String development = 'https://embedded-dev.bmoni.com';

  /// Alias for [development].
  static const String sandbox = development;

  /// Shared partner API key for sandbox testing against [development].
  ///
  /// Warning: This key only works against the development base URL.
  /// Organizations should get their own partner API key for production.
  static const String sandboxSharedApiKey =
      'pk_a025cacbf33a_76fb864113f3540909de5b1da39cc146906e35b1c6d4d1e4';

  /// Header name required for partner API key authentication.
  static const String apiKeyHeader = 'x-api-key';
}
