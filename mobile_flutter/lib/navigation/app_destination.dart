import 'package:flutter/widgets.dart';

/// Who owns a destination.
///
/// Exactly one owner per destination. The owner decides where the
/// destination may appear, which is what keeps a feature from having two
/// global entry points.
enum NavOwner {
  /// One of the four persistent dock tabs.
  dock,

  /// The centre launcher. It has no route.
  launcher,

  /// One of the four category hubs the fan opens.
  fanCategory,

  /// A feature that lives inside exactly one category hub.
  categoryFeature,

  /// A detail page under a feature.
  detail,
}

/// One destination in the app.
@immutable
class AppDestination {
  const AppDestination({
    required this.id,
    required this.title,
    required this.route,
    required this.owner,
    required this.icon,
    required this.semanticLabel,
    this.parentId,
  });

  /// The stable identifier used by the registry and the tests.
  final String id;

  /// The title shown in the UI.
  final String title;

  /// The canonical route. Empty for the launcher, which has no route.
  final String route;

  /// The single owner of this destination.
  final NavOwner owner;

  /// The outline icon for this destination.
  final IconData icon;

  /// The spoken label for screen readers.
  final String semanticLabel;

  /// The id of the parent destination, when there is one.
  final String? parentId;

  @override
  bool operator ==(Object other) =>
      other is AppDestination &&
      other.id == id &&
      other.title == title &&
      other.route == route &&
      other.owner == owner &&
      other.parentId == parentId;

  @override
  int get hashCode => Object.hash(id, title, route, owner, parentId);

  @override
  String toString() => 'AppDestination($id, $route)';
}
