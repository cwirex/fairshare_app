import 'package:fairshare_app/core/events/event_broker.dart';
import 'package:fairshare_app/core/events/event_broker_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'event_providers.g.dart';

/// Provider for the EventBroker instance.
///
/// Lifecycle managed by Riverpod (keepAlive: true for app-wide instance).
/// Automatically disposed when the provider container is disposed.
@Riverpod(keepAlive: true)
IEventBroker eventBroker(Ref ref) {
  final broker = EventBroker();
  ref.onDispose(broker.dispose);
  return broker;
}
