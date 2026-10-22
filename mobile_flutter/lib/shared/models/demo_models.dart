import 'package:flutter/foundation.dart';

/// A scheduled event.
@immutable
class ScheduleEvent {
  const ScheduleEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.room,
    required this.kind,
    this.note,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String room;

  /// `class`, `exam` or `personal`.
  final String kind;
  final String? note;

  /// The status of the event relative to now.
  EventStatus get status {
    final now = DateTime.now();
    if (now.isBefore(start)) return EventStatus.upcoming;
    if (now.isAfter(end)) return EventStatus.done;
    return EventStatus.now;
  }

  ScheduleEvent copyWith({String? title, String? room, String? note}) =>
      ScheduleEvent(
        id: id,
        title: title ?? this.title,
        start: start,
        end: end,
        room: room ?? this.room,
        kind: kind,
        note: note ?? this.note,
      );

  @override
  bool operator ==(Object other) => other is ScheduleEvent && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Where an event is in its life.
enum EventStatus { upcoming, now, done }

/// A task the student has to do.
@immutable
class PulseTask {
  const PulseTask({
    required this.id,
    required this.title,
    required this.course,
    required this.due,
    required this.priority,
    this.completed = false,
  });

  final String id;
  final String title;
  final String course;
  final DateTime due;

  /// `high`, `medium` or `low`.
  final String priority;
  final bool completed;

  PulseTask copyWith({bool? completed, String? title, String? course, DateTime? due, String? priority}) =>
      PulseTask(
        id: id,
        title: title ?? this.title,
        course: course ?? this.course,
        due: due ?? this.due,
        priority: priority ?? this.priority,
        completed: completed ?? this.completed,
      );

  @override
  bool operator ==(Object other) => other is PulseTask && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// An update posted to the student.
@immutable
class UpdateItem {
  const UpdateItem({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.publishedAt,
    this.read = false,
    this.saved = false,
  });

  final String id;
  final String title;
  final String body;

  /// `school`, `events` or `academic`.
  final String category;
  final DateTime publishedAt;
  final bool read;
  final bool saved;

  UpdateItem copyWith({bool? read, bool? saved}) => UpdateItem(
        id: id,
        title: title,
        body: body,
        category: category,
        publishedAt: publishedAt,
        read: read ?? this.read,
        saved: saved ?? this.saved,
      );

  @override
  bool operator ==(Object other) => other is UpdateItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A room on campus.
@immutable
class CampusRoom {
  const CampusRoom({
    required this.id,
    required this.name,
    required this.building,
    required this.floor,
    required this.capacity,
    required this.services,
  });

  final String id;
  final String name;
  final String building;
  final int floor;
  final int capacity;
  final List<String> services;
}

/// A person or a service in the directory.
@immutable
class DirectoryEntry {
  const DirectoryEntry({
    required this.id,
    required this.name,
    required this.role,
    required this.department,
    this.email,
    this.phone,
  });

  final String id;
  final String name;
  final String role;
  final String department;
  final String? email;
  final String? phone;
}

/// A lost or found item.
@immutable
class LostFoundItem {
  const LostFoundItem({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.reportedAt,
    required this.claimed,
  });

  final String id;
  final String name;
  final String category;
  final String location;
  final DateTime reportedAt;
  final bool claimed;

  LostFoundItem copyWith({bool? claimed}) => LostFoundItem(
        id: id,
        name: name,
        category: category,
        location: location,
        reportedAt: reportedAt,
        claimed: claimed ?? this.claimed,
      );
}

/// A library item.
@immutable
class LibraryItem {
  const LibraryItem({
    required this.id,
    required this.title,
    required this.author,
    required this.shelf,
    required this.available,
    this.featured = false,
  });

  final String id;
  final String title;
  final String author;
  final String shelf;
  final bool available;
  final bool featured;
}

/// A place on the campus map.
@immutable
class MapPlace {
  const MapPlace({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final String id;
  final String name;

  /// The position and size on the painted map, in map units.
  final double x;
  final double y;
  final double width;
  final double height;
}

/// A question and its answer.
@immutable
class FaqItem {
  const FaqItem({
    required this.id,
    required this.question,
    required this.answer,
  });

  final String id;
  final String question;
  final String answer;
}

/// A support path the student can take.
@immutable
class AssistancePath {
  const AssistancePath({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
  });

  final String id;
  final String title;
  final String description;
  final String iconName;
}
