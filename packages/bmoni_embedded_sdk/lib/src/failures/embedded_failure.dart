// SPDX-License-Identifier: Apache-2.0

/// Base failure class for all BMONI Embedded operations.
abstract class EmbeddedFailure {
  const EmbeddedFailure(this.message, {this.statusCode, this.details});

  /// Human-readable description of the failure.
  final String message;

  /// Optional HTTP status code associated with the error.
  final int? statusCode;

  /// Optional arbitrary payload / details returned by the server or system.
  final dynamic details;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmbeddedFailure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          statusCode == other.statusCode;

  @override
  int get hashCode => Object.hash(runtimeType, message, statusCode);

  @override
  String toString() => '$runtimeType(message: $message, statusCode: $statusCode)';
}

/// 5xx or unexpected server error response.
class EmbeddedServerFailure extends EmbeddedFailure {
  const EmbeddedServerFailure(
    super.message, {
    super.statusCode = 500,
    super.details,
  });
}

/// Local storage read/write error.
class EmbeddedCacheFailure extends EmbeddedFailure {
  const EmbeddedCacheFailure(super.message, {super.details});
}

/// Network connectivity loss, socket failure, or request timeout.
class EmbeddedNetworkFailure extends EmbeddedFailure {
  const EmbeddedNetworkFailure(super.message, {super.details});
}

/// Malformed request, invalid payload, or schema validation failure.
class EmbeddedValidationFailure extends EmbeddedFailure {
  const EmbeddedValidationFailure(
    super.message, {
    super.statusCode = 400,
    super.details,
  });
}

/// HTTP 429 rate limit exceeded.
class EmbeddedRateLimitFailure extends EmbeddedFailure {
  const EmbeddedRateLimitFailure(
    super.message, {
    super.statusCode = 429,
    super.details,
  });
}

/// HTTP 404 resource not found.
class EmbeddedNotFoundFailure extends EmbeddedFailure {
  const EmbeddedNotFoundFailure(
    super.message, {
    super.statusCode = 404,
    super.details,
  });
}

/// HTTP 401 unauthenticated (missing or invalid API key).
class EmbeddedAuthenticationFailure extends EmbeddedFailure {
  const EmbeddedAuthenticationFailure(
    super.message, {
    super.statusCode = 401,
    super.details,
  });
}

/// HTTP 403 forbidden (insufficient permissions).
class EmbeddedAuthorizationFailure extends EmbeddedFailure {
  const EmbeddedAuthorizationFailure(
    super.message, {
    super.statusCode = 403,
    super.details,
  });
}
