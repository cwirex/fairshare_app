import 'dart:async';

import 'package:fairshare_app/core/events/app_event.dart';
import 'package:fairshare_app/core/events/event_broker_interface.dart';
import 'package:fairshare_app/core/logging/app_logger.dart';

/// Event broker for broadcasting domain events.
///
/// Lifecycle managed by Riverpod providers, not a singleton.
class EventBroker with LoggerMixin implements IEventBroker {
  EventBroker() {
    log.i('EventBroker initialized');
  }

  final _controller = StreamController<AppEvent>.broadcast();

  /// Stream of all events.
  Stream<AppEvent> get stream => _controller.stream;

  /// Fire an event to all listeners.
  void fire(AppEvent event) {
    if (_controller.isClosed) {
      log.w('Attempted to fire event after EventBroker was closed: $event');
      return;
    }

    log.d('Event fired: $event');
    _controller.add(event);
  }

  /// Stream of specific event type.
  Stream<T> on<T extends AppEvent>() {
    return stream.where((event) => event is T).cast<T>();
  }

  /// Dispose the event broker.
  void dispose() {
    if (!_controller.isClosed) {
      log.i('EventBroker disposed');
      _controller.close();
    }
  }

  bool get isClosed => _controller.isClosed;
  bool get hasListeners => _controller.hasListener;
}
