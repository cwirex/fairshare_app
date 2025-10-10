import 'package:fairshare_app/core/logging/app_logger.dart';
import 'package:result_dart/result_dart.dart';

/// Generic interface for a use case with input and output types.
abstract class UseCase<Input, Output extends Object> with LoggerMixin {
  Future<Result<Output>> call(Input input);
}
