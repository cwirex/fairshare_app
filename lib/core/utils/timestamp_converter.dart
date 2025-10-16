import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

/// Custom JSON converter for Firestore Timestamps.
///
/// Handles conversion between:
/// - Firestore Timestamp objects (from Firestore)
/// - ISO 8601 strings (from local JSON serialization)
/// - DateTime objects (in Dart code)
class TimestampConverter implements JsonConverter<DateTime, Object> {
  const TimestampConverter();

  @override
  DateTime fromJson(Object json) {
    if (json is Timestamp) {
      // From Firestore
      return json.toDate();
    } else if (json is String) {
      // From local JSON (ISO 8601 string)
      return DateTime.parse(json);
    } else if (json is int) {
      // From milliseconds since epoch
      return DateTime.fromMillisecondsSinceEpoch(json);
    } else {
      throw ArgumentError(
        'Cannot convert $json (${json.runtimeType}) to DateTime',
      );
    }
  }

  @override
  Object toJson(DateTime dateTime) {
    // Always serialize to ISO 8601 string for local storage
    return dateTime.toIso8601String();
  }
}

/// Custom JSON converter for nullable Firestore Timestamps.
class NullableTimestampConverter implements JsonConverter<DateTime?, Object?> {
  const NullableTimestampConverter();

  @override
  DateTime? fromJson(Object? json) {
    if (json == null) {
      return null;
    }
    return const TimestampConverter().fromJson(json);
  }

  @override
  Object? toJson(DateTime? dateTime) {
    if (dateTime == null) {
      return null;
    }
    return const TimestampConverter().toJson(dateTime);
  }
}
