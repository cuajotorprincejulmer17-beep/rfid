import 'package:flutter/material.dart';

import 'app_destination.dart';

/// Every destination in the app, declared exactly once.
///
/// The registry is the single source of truth for navigation. The router
/// builds its routes from this list, the dock renders the dock-owned
/// entries, the fan renders the fan-owned entries, and each category hub
/// renders the features the registry places under it. A feature can
/// therefore never appear in two places, and a deep link always reuses the
/// canonical route.
const List<AppDestination> kDestinations = <AppDestination>[
  // ---------------------------------------------------------- dock branches
  AppDestination(
    id: 'home',
    title: 'Home',
    route: '/home',
    owner: NavOwner.dock,
    icon: Icons.home_outlined,
    semanticLabel: 'Home',
  ),
  AppDestination(
    id: 'schedule',
    title: 'Schedule',
    route: '/schedule',
    owner: NavOwner.dock,
    icon: Icons.calendar_today_outlined,
    semanticLabel: 'Schedule',
  ),
  AppDestination(
    id: 'tasks',
    title: 'Tasks',
    route: '/tasks',
    owner: NavOwner.dock,
    icon: Icons.task_alt_outlined,
    semanticLabel: 'Tasks',
  ),
  AppDestination(
    id: 'updates',
    title: 'Updates',
    route: '/updates',
    owner: NavOwner.dock,
    icon: Icons.campaign_outlined,
    semanticLabel: 'Updates',
  ),

  // ------------------------------------------------------------- the launcher
  AppDestination(
    id: 'pulse',
    title: 'Pulse',
    route: '',
    owner: NavOwner.launcher,
    icon: Icons.bolt_rounded,
    semanticLabel: 'Open Pulse menu',
  ),

  // -------------------------------------------------------- the fan categories
  AppDestination(
    id: 'academic',
    title: 'Academic',
    route: '/academic',
    owner: NavOwner.fanCategory,
    icon: Icons.school_outlined,
    semanticLabel: 'Academic',
  ),
  AppDestination(
    id: 'campus',
    title: 'Campus',
    route: '/campus',
    owner: NavOwner.fanCategory,
    icon: Icons.apartment_outlined,
    semanticLabel: 'Campus',
  ),
  AppDestination(
    id: 'personal',
    title: 'Personal',
    route: '/personal',
    owner: NavOwner.fanCategory,
    icon: Icons.person_outline,
    semanticLabel: 'Personal',
  ),
  AppDestination(
    id: 'support',
    title: 'Support',
    route: '/support',
    owner: NavOwner.fanCategory,
    icon: Icons.help_outline,
    semanticLabel: 'Support',
  ),

  // ----------------------------------------------------------------- academic
  AppDestination(
    id: 'attendance',
    title: 'Attendance',
    route: '/academic/attendance',
    owner: NavOwner.categoryFeature,
    parentId: 'academic',
    icon: Icons.credit_card_outlined,
    semanticLabel: 'Attendance',
  ),
  AppDestination(
    id: 'insights',
    title: 'Workload and Insights',
    route: '/academic/insights',
    owner: NavOwner.categoryFeature,
    parentId: 'academic',
    icon: Icons.insights_outlined,
    semanticLabel: 'Workload and Insights',
  ),
  AppDestination(
    id: 'history',
    title: 'Academic History',
    route: '/academic/history',
    owner: NavOwner.categoryFeature,
    parentId: 'academic',
    icon: Icons.history_outlined,
    semanticLabel: 'Academic History',
  ),

  // ------------------------------------------------------------------- campus
  AppDestination(
    id: 'digital-id',
    title: 'Digital ID',
    route: '/campus/digital-id',
    owner: NavOwner.categoryFeature,
    parentId: 'campus',
    icon: Icons.badge_outlined,
    semanticLabel: 'Digital ID',
  ),
  AppDestination(
    id: 'rooms',
    title: 'Room Finder',
    route: '/campus/rooms',
    owner: NavOwner.categoryFeature,
    parentId: 'campus',
    icon: Icons.meeting_room_outlined,
    semanticLabel: 'Room Finder',
  ),
  AppDestination(
    id: 'directory',
    title: 'Directory',
    route: '/campus/directory',
    owner: NavOwner.categoryFeature,
    parentId: 'campus',
    icon: Icons.people_outline,
    semanticLabel: 'Directory',
  ),
  AppDestination(
    id: 'lost-found',
    title: 'Lost and Found',
    route: '/campus/lost-found',
    owner: NavOwner.categoryFeature,
    parentId: 'campus',
    icon: Icons.inventory_2_outlined,
    semanticLabel: 'Lost and Found',
  ),
  AppDestination(
    id: 'library',
    title: 'Library',
    route: '/campus/library',
    owner: NavOwner.categoryFeature,
    parentId: 'campus',
    icon: Icons.menu_book_outlined,
    semanticLabel: 'Library',
  ),
  AppDestination(
    id: 'map',
    title: 'Map',
    route: '/campus/map',
    owner: NavOwner.categoryFeature,
    parentId: 'campus',
    icon: Icons.map_outlined,
    semanticLabel: 'Map',
  ),

  // ----------------------------------------------------------------- personal
  AppDestination(
    id: 'profile',
    title: 'Profile',
    route: '/personal/profile',
    owner: NavOwner.categoryFeature,
    parentId: 'personal',
    icon: Icons.person_outline,
    semanticLabel: 'Profile',
  ),
  AppDestination(
    id: 'appearance',
    title: 'Appearance',
    route: '/personal/appearance',
    owner: NavOwner.categoryFeature,
    parentId: 'personal',
    icon: Icons.palette_outlined,
    semanticLabel: 'Appearance',
  ),
  AppDestination(
    id: 'settings',
    title: 'Settings',
    route: '/personal/settings',
    owner: NavOwner.categoryFeature,
    parentId: 'personal',
    icon: Icons.settings_outlined,
    semanticLabel: 'Settings',
  ),

  // ------------------------------------------------------------------ support
  AppDestination(
    id: 'assistance',
    title: 'Assistance',
    route: '/support/assistance',
    owner: NavOwner.categoryFeature,
    parentId: 'support',
    icon: Icons.support_agent_outlined,
    semanticLabel: 'Assistance',
  ),
  AppDestination(
    id: 'faq',
    title: 'FAQ',
    route: '/support/faq',
    owner: NavOwner.categoryFeature,
    parentId: 'support',
    icon: Icons.quiz_outlined,
    semanticLabel: 'Frequently asked questions',
  ),
  AppDestination(
    id: 'contact',
    title: 'Contact Support',
    route: '/support/contact',
    owner: NavOwner.categoryFeature,
    parentId: 'support',
    icon: Icons.chat_bubble_outline,
    semanticLabel: 'Contact Support',
  ),

  // ------------------------------------------------------------ detail routes
  AppDestination(
    id: 'schedule-event',
    title: 'Event',
    route: '/schedule/event/:id',
    owner: NavOwner.detail,
    parentId: 'schedule',
    icon: Icons.event_outlined,
    semanticLabel: 'Event',
  ),
  AppDestination(
    id: 'task-detail',
    title: 'Task',
    route: '/tasks/:id',
    owner: NavOwner.detail,
    parentId: 'tasks',
    icon: Icons.task_alt_outlined,
    semanticLabel: 'Task',
  ),
  AppDestination(
    id: 'update-detail',
    title: 'Update',
    route: '/updates/:id',
    owner: NavOwner.detail,
    parentId: 'updates',
    icon: Icons.campaign_outlined,
    semanticLabel: 'Update',
  ),
  AppDestination(
    id: 'attendance-history',
    title: 'Attendance History',
    route: '/academic/attendance/history',
    owner: NavOwner.detail,
    parentId: 'attendance',
    icon: Icons.history_outlined,
    semanticLabel: 'Attendance History',
  ),
  AppDestination(
    id: 'room-detail',
    title: 'Room',
    route: '/campus/rooms/:id',
    owner: NavOwner.detail,
    parentId: 'rooms',
    icon: Icons.meeting_room_outlined,
    semanticLabel: 'Room',
  ),
  AppDestination(
    id: 'lost-found-new',
    title: 'Report Lost Item',
    route: '/campus/lost-found/new',
    owner: NavOwner.detail,
    parentId: 'lost-found',
    icon: Icons.add_circle_outline,
    semanticLabel: 'Report a lost item',
  ),
  AppDestination(
    id: 'lost-found-detail',
    title: 'Lost Item',
    route: '/campus/lost-found/:id',
    owner: NavOwner.detail,
    parentId: 'lost-found',
    icon: Icons.inventory_2_outlined,
    semanticLabel: 'Lost item',
  ),
  AppDestination(
    id: 'library-item',
    title: 'Library Item',
    route: '/campus/library/:id',
    owner: NavOwner.detail,
    parentId: 'library',
    icon: Icons.menu_book_outlined,
    semanticLabel: 'Library item',
  ),
  AppDestination(
    id: 'map-place',
    title: 'Place',
    route: '/campus/map/:id',
    owner: NavOwner.detail,
    parentId: 'map',
    icon: Icons.place_outlined,
    semanticLabel: 'Place',
  ),
  AppDestination(
    id: 'faq-item',
    title: 'FAQ Answer',
    route: '/support/faq/:id',
    owner: NavOwner.detail,
    parentId: 'faq',
    icon: Icons.quiz_outlined,
    semanticLabel: 'FAQ answer',
  ),
];

/// The four dock branches, in the order the dock draws them.
final List<AppDestination> dockDestinations = kDestinations
    .where((d) => d.owner == NavOwner.dock)
    .toList(growable: false);

/// The launcher. It has no route.
final AppDestination launcherDestination =
    kDestinations.firstWhere((d) => d.owner == NavOwner.launcher);

/// The four category hubs the fan opens.
final List<AppDestination> fanCategories = kDestinations
    .where((d) => d.owner == NavOwner.fanCategory)
    .toList(growable: false);

/// Every destination indexed by id.
final Map<String, AppDestination> destinationById = <String, AppDestination>{
  for (final d in kDestinations) d.id: d,
};

/// The features the registry places under [categoryId].
///
/// A category hub renders exactly this list, so a feature can only ever
/// appear under one parent.
List<AppDestination> featuresOf(String categoryId) => kDestinations
    .where((d) => d.owner == NavOwner.categoryFeature && d.parentId == categoryId)
    .toList(growable: false);

/// Looks a destination up by id, or null when it is not registered.
AppDestination? lookupDestination(String id) => destinationById[id];

/// The canonical route for a destination id, or null when it is unknown.
String? routeForId(String id) => destinationById[id]?.route;

/// The icons used by the fan items, in category order.
List<IconData> get fanCategoryIcons =>
    fanCategories.map((d) => d.icon).toList(growable: false);
