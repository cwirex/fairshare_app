import 'package:fairshare_app/core/events/app_event.dart';
import 'package:fairshare_app/core/events/event_broker.dart';
import 'package:fairshare_app/core/events/expense_events.dart';
import 'package:fairshare_app/core/events/group_events.dart';
import 'package:fairshare_app/features/expenses/domain/entities/expense_entity.dart';
import 'package:fairshare_app/features/groups/domain/entities/group_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EventBroker', () {
    late EventBroker eventBroker;

    setUp(() {
      eventBroker = EventBroker();
    });

    tearDown(() {
      // Note: EventBroker is a singleton, so we can't fully dispose it
      // between tests. In real usage, it's managed by Riverpod.
    });

    test('fires events to stream listeners', () async {
      // Arrange
      final expense = ExpenseEntity(
        id: 'exp1',
        groupId: 'group1',
        title: 'Test Expense',
        amount: 100.0,
        currency: 'USD',
        paidBy: 'user1',
        expenseDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final event = ExpenseCreated(expense);

      // Act & Assert
      expectLater(eventBroker.stream, emits(event));

      eventBroker.fire(event);
    });

    test('fires events to multiple listeners', () async {
      // Arrange
      final expense = ExpenseEntity(
        id: 'exp2',
        groupId: 'group1',
        title: 'Another Expense',
        amount: 50.0,
        currency: 'USD',
        paidBy: 'user1',
        expenseDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final event = ExpenseCreated(expense);

      final listener1Events = <AppEvent>[];
      final listener2Events = <AppEvent>[];

      // Act
      eventBroker.stream.listen(listener1Events.add);
      eventBroker.stream.listen(listener2Events.add);

      eventBroker.fire(event);

      // Wait for events to propagate
      await Future.delayed(Duration(milliseconds: 10));

      // Assert
      expect(listener1Events, contains(event));
      expect(listener2Events, contains(event));
    });

    test('on<T>() filters events by type', () async {
      // Arrange
      final expense = ExpenseEntity(
        id: 'exp3',
        groupId: 'group1',
        title: 'Filtered Expense',
        amount: 75.0,
        currency: 'USD',
        paidBy: 'user1',
        expenseDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final group = GroupEntity(
        id: 'group1',
        displayName: 'Test Group',
        avatarUrl: '',
        isPersonal: false,
        defaultCurrency: 'USD',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        lastActivityAt: DateTime.now(),
      );

      final expenseEvent = ExpenseCreated(expense);
      final groupEvent = GroupCreated(group);

      // Act & Assert
      expectLater(
        eventBroker.on<ExpenseCreated>(),
        emitsInOrder([expenseEvent]),
      );

      // Fire both events
      eventBroker.fire(expenseEvent);
      eventBroker.fire(groupEvent);
    });

    test('on<T>() with multiple event types', () async {
      // Arrange
      final expense = ExpenseEntity(
        id: 'exp4',
        groupId: 'group1',
        title: 'Multi-type Test',
        amount: 25.0,
        currency: 'USD',
        paidBy: 'user1',
        expenseDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final createEvent = ExpenseCreated(expense);
      final updateEvent = ExpenseUpdated(expense);
      final deleteEvent = ExpenseDeleted('exp4', 'group1');

      final expenseEvents = <AppEvent>[];
      final createdEvents = <ExpenseCreated>[];

      // Act
      eventBroker.stream
          .where((e) => e is ExpenseCreated || e is ExpenseUpdated)
          .listen(expenseEvents.add);

      eventBroker.on<ExpenseCreated>().listen(createdEvents.add);

      eventBroker.fire(createEvent);
      eventBroker.fire(updateEvent);
      eventBroker.fire(deleteEvent);

      await Future.delayed(Duration(milliseconds: 10));

      // Assert
      expect(expenseEvents.length, 2); // Only create and update
      expect(createdEvents.length, 1); // Only create
      expect(createdEvents.first, createEvent);
    });

    test('hasListeners returns true when there are active listeners', () async {
      // Act
      final subscription = eventBroker.stream.listen((_) {});

      // Assert
      expect(eventBroker.hasListeners, isTrue);

      // Cleanup
      await subscription.cancel();
    });

    test('events contain timestamp', () {
      // Arrange
      final expense = ExpenseEntity(
        id: 'exp5',
        groupId: 'group1',
        title: 'Timestamp Test',
        amount: 10.0,
        currency: 'USD',
        paidBy: 'user1',
        expenseDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Act
      final event = ExpenseCreated(expense);

      // Assert
      expect(event.timestamp, isA<DateTime>());
      expect(
        event.timestamp.isBefore(DateTime.now().add(Duration(seconds: 1))),
        isTrue,
      );
    });

    test('affectsGroup extension filters correctly', () {
      // Arrange
      final expense1 = ExpenseEntity(
        id: 'exp6',
        groupId: 'group1',
        title: 'Group 1 Expense',
        amount: 30.0,
        currency: 'USD',
        paidBy: 'user1',
        expenseDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final expense2 = ExpenseEntity(
        id: 'exp7',
        groupId: 'group2',
        title: 'Group 2 Expense',
        amount: 40.0,
        currency: 'USD',
        paidBy: 'user1',
        expenseDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final event1 = ExpenseCreated(expense1);
      final event2 = ExpenseCreated(expense2);

      // Assert
      expect(event1.affectsGroup('group1'), isTrue);
      expect(event1.affectsGroup('group2'), isFalse);
      expect(event2.affectsGroup('group2'), isTrue);
      expect(event2.affectsGroup('group1'), isFalse);
    });

    test('isExpenseEvent extension identifies expense events', () {
      // Arrange
      final expense = ExpenseEntity(
        id: 'exp8',
        groupId: 'group1',
        title: 'Event Type Test',
        amount: 20.0,
        currency: 'USD',
        paidBy: 'user1',
        expenseDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final group = GroupEntity(
        id: 'group1',
        displayName: 'Test Group',
        avatarUrl: '',
        isPersonal: false,
        defaultCurrency: 'USD',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        lastActivityAt: DateTime.now(),
      );

      final expenseEvent = ExpenseCreated(expense);
      final groupEvent = GroupCreated(group);

      // Assert
      expect(expenseEvent.isExpenseEvent(), isTrue);
      expect(expenseEvent.isGroupEvent(), isFalse);
      expect(groupEvent.isExpenseEvent(), isFalse);
      expect(groupEvent.isGroupEvent(), isTrue);
    });
  });
}
