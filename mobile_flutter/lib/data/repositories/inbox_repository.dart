import '../../core/api/api_client.dart';
import '../models/models.dart';

/// Reads and marks the notification inbox.
///
/// The inbox is the only notification channel in Phase 1: push registration is
/// Expo-only on the server, and Flutter would need FCM. That is a separate
/// backend proposal, so this app polls and pulls to refresh instead. It never
/// claims a push was delivered.
class InboxRepository {
  InboxRepository(this._api);

  final ApiClient _api;

  /// `GET /notifications`.
  Future<InboxPage> fetch({
    String? category,
    bool unreadOnly = false,
    int limit = 30,
    int? before,
  }) async {
    final query = <String, String>{'limit': '$limit'};
    if (category != null) query['category'] = category;
    if (unreadOnly) query['unread'] = '1';
    if (before != null) query['before'] = '$before';
    final json = await _api.getJson('/notifications', query: query);
    return InboxPage.fromJson(json);
  }

  /// `GET /notifications/unread-count`.
  Future<({int total, Map<String, int> byCategory})> fetchUnreadCount() async {
    final json = await _api.getJson('/notifications/unread-count');
    final raw = json['by_category'];
    final byCategory = <String, int>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        if (value is num) byCategory['$key'] = value.toInt();
      });
    }
    return (total: (json['total'] as num?)?.toInt() ?? 0, byCategory: byCategory);
  }

  /// `POST /notifications/<id>/read`.
  Future<InboxItem> markRead(int id) async {
    final json = await _api.postJson('/notifications/$id/read');
    return InboxItem.fromJson(json);
  }

  /// `POST /notifications/read-all`. [category] limits it to one category.
  Future<int> markAllRead({String? category}) async {
    final json = await _api.postJson(
      '/notifications/read-all',
      category == null ? <String, dynamic>{} : {'category': category},
    );
    return (json['updated'] as num?)?.toInt() ?? 0;
  }
}
