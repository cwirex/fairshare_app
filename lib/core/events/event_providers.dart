import 'package:fairshare_app/core/events/event_broker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'event_providers.g.dart';

/// Provider for the singleton EventBroker instance.
@Riverpod(keepAlive: true)
EventBroker eventBroker(Ref ref) {
  final broker = EventBroker();
  ref.onDispose(broker.dispose);
  return broker;
}
