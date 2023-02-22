//
// exceptions.dart
// Exceptions for the library
//
// Author: Max Korbel
// 2023 February 21
//

/// An [Exception] for the ROHD Hardware Component Library.
class RohdHclException implements Exception {
  /// A message explaining this [Exception].
  final String message;

  /// Creates an [Exception] for the ROHD Hardware Component Library.
  RohdHclException(this.message);
}
