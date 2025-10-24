import 'dart:async';

import 'package:fairshare_app/core/events/app_event.dart';

/// Interface for event broadcasting and subscription.
///
/// Provides a decoupled way for components to communicate via domain events
/// without direct dependencies.
abstract class IEventBroker {
  /// Stream of all events.
  Stream<AppEvent> get stream;

  /// Fire an event to all listeners.
  void fire(AppEvent event);

  /// Stream of specific event type.
  Stream<T> on<T extends AppEvent>();

  /// Dispose the event broker and release resources.
  void dispose();

  /// Whether the event broker has been disposed.
  bool get isClosed;

  /// Whether there are any active listeners.
  bool get hasListeners;
}
