import '../../auth/services/auth_required_guard.dart';
import '../models/group_category.dart';
import '../models/group_join_request.dart';
import '../models/group_message.dart';
import '../models/social_group.dart';
import '../services/group_join_result.dart';
import 'social_group_repository.dart';

/// V1.3.3 — guest write korumalı [SocialGroupRepository] dekoratörü.
class GuardedSocialGroupRepository implements SocialGroupRepository {
  GuardedSocialGroupRepository({
    required this.inner,
    required this.canWriteCheck,
  });

  final SocialGroupRepository inner;
  final bool Function() canWriteCheck;

  void _requireWrite(String action) {
    if (!canWriteCheck()) {
      throw GuestActionRequiredException(action: action);
    }
  }

  // ── Read ────────────────────────────────────────────

  @override
  Future<List<SocialGroup>> listGroups({GroupCategory? category}) =>
      inner.listGroups(category: category);

  @override
  Future<List<SocialGroup>> listPopular({int limit = 6}) =>
      inner.listPopular(limit: limit);

  @override
  Future<List<SocialGroup>> listJoined() => inner.listJoined();

  @override
  Future<SocialGroup?> getGroup(String id) => inner.getGroup(id);

  @override
  bool isJoined(String id) => inner.isJoined(id);

  @override
  Future<List<GroupMessage>> listMessages(String groupId) =>
      inner.listMessages(groupId);

  @override
  Stream<void> watch() => inner.watch();

  // ── Write (guarded) ────────────────────────────────

  @override
  Future<SocialGroup> createGroup({
    required String name,
    required String description,
    required GroupCategory category,
    String city = '',
    bool isPrivate = false,
    int? maxMembers,
    List<String> tags = const <String>[],
  }) {
    _requireWrite('grup oluşturmak');
    return inner.createGroup(
      name: name,
      description: description,
      category: category,
      city: city,
      isPrivate: isPrivate,
      maxMembers: maxMembers,
      tags: tags,
    );
  }

  @override
  Future<GroupJoinResult> joinGroup(String id) {
    _requireWrite('gruba katılmak');
    return inner.joinGroup(id);
  }

  @override
  Future<void> leaveGroup(String id) {
    _requireWrite('gruptan ayrılmak');
    return inner.leaveGroup(id);
  }

  @override
  Future<void> postMessage(GroupMessage m) {
    _requireWrite('grup mesajı göndermek');
    return inner.postMessage(m);
  }

  // ── Private join requests (V1 P1-D) ────────────────────────────

  @override
  Future<GroupJoinRequest> requestJoinGroup(
    String groupId, {
    String? message,
  }) {
    _requireWrite('katılma isteği göndermek');
    return inner.requestJoinGroup(groupId, message: message);
  }

  /// Read-only — guest user de okuyabilir (auth gerekirse Supabase RLS keser).
  @override
  Future<GroupJoinRequest?> getMyJoinRequest(String groupId) =>
      inner.getMyJoinRequest(groupId);

  @override
  Future<List<GroupJoinRequest>> listPendingJoinRequests(String groupId) =>
      inner.listPendingJoinRequests(groupId);

  @override
  Future<GroupJoinRequest> approveJoinRequest(String requestId) {
    _requireWrite('katılım isteğini onaylamak');
    return inner.approveJoinRequest(requestId);
  }

  @override
  Future<GroupJoinRequest> rejectJoinRequest(String requestId) {
    _requireWrite('katılım isteğini reddetmek');
    return inner.rejectJoinRequest(requestId);
  }
}
