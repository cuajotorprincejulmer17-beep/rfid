import 'app_destination.dart';

/// Checks the structural rules the registry must obey.
///
/// Returns a list of problems. An empty list means the registry is valid.
/// The rules are the guard rails from the specification:
///  * the dock is exactly Home, Schedule, Tasks and Updates,
///  * exactly one launcher exists and it has no route,
///  * the fan holds only category hubs,
///  * no feature appears under two parents,
///  * every route is unique,
///  * Profile, Settings and Appearance live under Personal,
///  * there is no global More destination.
List<String> validateRegistry(List<AppDestination> all) {
  final problems = <String>[];
  final ids = <String>{};
  final routes = <String>{};

  for (final d in all) {
    if (!ids.add(d.id)) {
      problems.add('Duplicate id: ${d.id}');
    }
    if (d.owner != NavOwner.launcher && d.route.isEmpty) {
      problems.add('Missing route: ${d.id}');
    }
    if (d.route.isNotEmpty && !routes.add(d.route)) {
      problems.add('Duplicate route: ${d.route}');
    }
  }

  final byId = <String, AppDestination>{for (final d in all) d.id: d};
  List<AppDestination> owned(NavOwner owner) =>
      all.where((d) => d.owner == owner).toList();

  const dockIds = <String>['home', 'schedule', 'tasks', 'updates'];
  final dock = owned(NavOwner.dock);
  if (dock.length != dockIds.length || !dock.every((d) => dockIds.contains(d.id))) {
    problems.add('Dock must be exactly home, schedule, tasks, updates');
  }

  final launchers = owned(NavOwner.launcher);
  if (launchers.length != 1 || launchers.single.route.isNotEmpty) {
    problems.add('Exactly one route-less launcher is required');
  }

  final fan = owned(NavOwner.fanCategory);
  if (fan.length < 3 || fan.length > 5) {
    problems.add('The fan must contain 3 to 5 category hubs');
  }
  for (final f in fan) {
    if (dockIds.contains(f.id)) {
      problems.add('Dock destination appears in the fan: ${f.id}');
    }
  }

  final titles = <String>{};
  for (final d in all.where((d) => d.owner != NavOwner.detail)) {
    if (!titles.add(d.title.toLowerCase())) {
      problems.add('Duplicate title across global areas: ${d.title}');
    }
  }

  for (final d in owned(NavOwner.categoryFeature)) {
    final parent = byId[d.parentId];
    if (parent == null || parent.owner != NavOwner.fanCategory) {
      problems.add('Feature ${d.id} needs a fan category parent');
    } else if (!d.route.startsWith('${parent.route}/')) {
      problems.add('Route of ${d.id} must live under ${parent.route}');
    }
  }

  for (final d in owned(NavOwner.detail)) {
    final parent = byId[d.parentId];
    if (parent == null) {
      problems.add('Detail ${d.id} needs a parent');
    } else if (!d.route.startsWith('${parent.route}/')) {
      problems.add('Detail route of ${d.id} must live under ${parent.route}');
    }
  }

  for (final id in const <String>['profile', 'settings', 'appearance']) {
    if (byId[id]?.parentId != 'personal') {
      problems.add('$id must live under Personal');
    }
  }

  if (byId.containsKey('more')) {
    problems.add('A global More destination is forbidden');
  }

  return problems;
}
