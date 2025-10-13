import 'package:fairshare_app/core/logging/app_logger.dart';
import 'package:meta/meta.dart';
import 'package:result_dart/result_dart.dart';

/// Generic interface for a use case with input and output types.
abstract class UseCase<Input, Output extends Object> with LoggerMixin {
  /// Executes the use case with the given input.
  ///
  /// This method orchestrates validation and execution:
  /// 1. Calls [validate] which may throw if input is invalid
  /// 2. Calls [execute] to perform business logic
  /// 3. Wraps the result in [Success] or [Failure]
  ///
  /// Returns a [Result] containing either the output or an exception.
  Future<Result<Output>> call(Input input) async {
    try {
      // Validate first (may throw)
      validate(input);

      // Execute business logic
      final result = await execute(input);
      return Success(result);
    } catch (e) {
      log.e('Use case failed: $e');
      return Failure(e is Exception ? e : Exception(e.toString()));
    }
  }

  /// Validates the input before execution.
  ///
  /// Override this method to add validation logic.
  /// Throw an [Exception] if validation fails.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// void validate(MyInput input) {
  ///   if (input.value.isEmpty) {
  ///     throw Exception('Value is required');
  ///   }
  /// }
  /// ```
  @protected
  void validate(Input input) {}

  /// Executes the use case business logic.
  ///
  /// Do not call directly - always use [call] instead.
  /// Can throw exceptions which will be caught and wrapped in Result.
  @protected
  Future<Output> execute(Input input);
}
