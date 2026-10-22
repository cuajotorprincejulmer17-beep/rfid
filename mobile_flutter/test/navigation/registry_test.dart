import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/navigation/app_destination.dart';
import 'package:pulse_flutter/navigation/destination_registry.dart';
import 'package:pulse_flutter/navigation/registry_validator.dart';

/// A destination with every field set, for building negative cases.
AppDestination _dest(
  String id, {
  String? route,
  NavOwner owner = NavOwner.categoryFeature,
  String? parentId,
  String title = 'Title',
}) {
  return AppDestination(
    id: id,
    title: title,
    route: route ?? '/$id',
    owner: owner,
    icon: Icons.circle_outlined,
    semanticLabel: id,
    parentId: parentId,
  );
}

void main() {
  group('The registry is valid', () {
    test('validateRegistry reports no problems', () {
      expect(validateRegistry(kDestinations), isEmpty);
    });
  });

  group('The dock', () {
    test('is exactly home, schedule, tasks and updates', () {
      expect(
        dockDestinations.map((d) => d.id).toList(),
        <String>['home', 'schedule', 'tasks', 'updates'],
      );
    });

    test('every dock destination owns its own route', () {
      for (final d in dockDestinations) {
        expect(d.route, isNotEmpty);
        expect(d.owner, NavOwner.dock);
      }
    });
  });

  group('The launcher', () {
    test('is exactly one', () {
      final launchers =
          kDestinations.where((d) => d.owner == NavOwner.launcher).toList();
      expect(launchers, hasLength(1));
    });

    test('has no route', () {
      expect(launcherDestination.route, isEmpty);
    });

    test('never opens a dock destination', () {
      expect(launcherDestination.owner, isNot(NavOwner.dock));
      final dockRoutes = dockDestinations.map((d) => d.route).toSet();
      expect(dockRoutes.contains(launcherDestination.route), isFalse);
    });
  });

  group('The fan', () {
    test('holds exactly academic, campus, personal and support', () {
      expect(
        fanCategories.map((d) => d.id).toList(),
        <String>['academic', 'campus', 'personal', 'support'],
      );
    });

    test('never holds a dock destination', () {
      final dockIds = dockDestinations.map((d) => d.id).toSet();
      for (final category in fanCategories) {
        expect(dockIds.contains(category.id), isFalse);
      }
    });

    test('never holds an individual feature', () {
      for (final category in fanCategories) {
        expect(category.owner, NavOwner.fanCategory);
      }
    });
  });

  group('Feature ownership', () {
    test('no feature appears under two parents', () {
      final parents = <String, String>{};
      for (final d
          in kDestinations.where((d) => d.owner == NavOwner.categoryFeature)) {
        final existing = parents[d.id];
        expect(
          existing,
          anyOf(isNull, d.parentId),
          reason: '${d.id} is listed under two parents',
        );
        parents[d.id] = d.parentId!;
      }
    });

    test('every route is unique', () {
      final routes = kDestinations
          .where((d) => d.route.isNotEmpty)
          .map((d) => d.route)
          .toList();
      expect(routes.toSet().length, routes.length);
    });

    test('every feature lives under exactly one category', () {
      for (final category in fanCategories) {
        final features = featuresOf(category.id);
        expect(features, isNotEmpty);
        for (final feature in features) {
          expect(feature.parentId, category.id);
        }
      }
    });

    test('the four categories hold the documented features', () {
      expect(
        featuresOf('academic').map((d) => d.id).toList(),
        <String>['attendance', 'insights', 'history'],
      );
      expect(
        featuresOf('campus').map((d) => d.id).toList(),
        <String>[
          'digital-id',
          'rooms',
          'directory',
          'lost-found',
          'library',
          'map',
        ],
      );
      expect(
        featuresOf('personal').map((d) => d.id).toList(),
        <String>['profile', 'appearance', 'settings'],
      );
      expect(
        featuresOf('support').map((d) => d.id).toList(),
        <String>['assistance', 'faq', 'contact'],
      );
    });
  });

  group('Personal', () {
    test('holds profile, settings and appearance', () {
      for (final id in const ['profile', 'settings', 'appearance']) {
        expect(destinationById[id]!.parentId, 'personal');
      }
    });
  });

  group('There is no More', () {
    test('no destination has the id "more"', () {
      expect(destinationById.containsKey('more'), isFalse);
    });

    test('no destination is titled More', () {
      for (final d in kDestinations) {
        expect(d.title.toLowerCase(), isNot('more'));
      }
    });
  });

  group('Negative cases', () {
    test('a duplicate id is reported', () {
      final problems = validateRegistry(<AppDestination>[
        _dest('a', title: 'A'),
        _dest('a', title: 'B'),
      ]);
      expect(problems, contains('Duplicate id: a'));
    });

    test('a duplicate route is reported', () {
      final problems = validateRegistry(<AppDestination>[
        _dest('a', route: '/same', title: 'A'),
        _dest('b', route: '/same', title: 'B'),
      ]);
      expect(problems, contains('Duplicate route: /same'));
    });

    test('a missing route is reported', () {
      final problems = validateRegistry(<AppDestination>[
        _dest('a', route: '', title: 'A'),
      ]);
      expect(problems, contains('Missing route: a'));
    });

    test('a dock destination inside the fan is reported', () {
      final problems = validateRegistry(<AppDestination>[
        _dest('home', owner: NavOwner.fanCategory, title: 'Home'),
        _dest('academic', owner: NavOwner.fanCategory, title: 'Academic'),
        _dest('campus', owner: NavOwner.fanCategory, title: 'Campus'),
        _dest('personal', owner: NavOwner.fanCategory, title: 'Personal'),
        _dest('support', owner: NavOwner.fanCategory, title: 'Support'),
      ]);
      expect(problems, contains('Dock destination appears in the fan: home'));
    });

    test('a feature with no category parent is reported', () {
      final problems = validateRegistry(<AppDestination>[
        _dest('orphan', parentId: null, title: 'Orphan'),
      ]);
      expect(problems, contains('Feature orphan needs a fan category parent'));
    });

    test('a feature whose route escapes its parent is reported', () {
      final problems = validateRegistry(<AppDestination>[
        _dest('academic', owner: NavOwner.fanCategory, title: 'Academic'),
        _dest('campus', owner: NavOwner.fanCategory, title: 'Campus'),
        _dest('personal', owner: NavOwner.fanCategory, title: 'Personal'),
        _dest('support', owner: NavOwner.fanCategory, title: 'Support'),
        _dest('escape', route: '/elsewhere/thing', parentId: 'academic', title: 'Escape'),
      ]);
      expect(
        problems,
        contains('Route of escape must live under /academic'),
      );
    });

    test('a global More destination is reported', () {
      final problems = validateRegistry(<AppDestination>[
        _dest('more', owner: NavOwner.fanCategory, title: 'More'),
      ]);
      expect(problems, contains('A global More destination is forbidden'));
    });

    test('a second launcher is reported', () {
      final problems = validateRegistry(<AppDestination>[
        _dest('pulse', owner: NavOwner.launcher, route: '', title: 'Pulse'),
        _dest('pulse2', owner: NavOwner.launcher, route: '', title: 'Pulse Two'),
      ]);
      expect(
        problems,
        contains('Exactly one route-less launcher is required'),
      );
    });

    test('a duplicate title across global areas is reported', () {
      final problems = validateRegistry(<AppDestination>[
        _dest('a', title: 'Same'),
        _dest('b', title: 'Same'),
      ]);
      expect(
        problems,
        contains('Duplicate title across global areas: Same'),
      );
    });

    test('profile outside Personal is reported', () {
      final problems = validateRegistry(<AppDestination>[
        _dest('profile', parentId: 'campus', title: 'Profile'),
      ]);
      expect(problems, contains('profile must live under Personal'));
    });
  });
}
