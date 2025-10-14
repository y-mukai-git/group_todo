import 'package:flutter/foundation.dart';
import '../core/utils/api_client.dart';
import '../data/models/group_model.dart';

/// グループ管理サービス
class GroupService {
  final ApiClient _apiClient = ApiClient();

  /// グループ作成
  Future<GroupModel> createGroup({
    required String userId,
    required String groupName,
    String? imageData,
    String? description,
    String? category,
  }) async {
    try {
      final body = {
        'user_id': userId,
        'name': groupName,
        if (imageData != null) 'image_data': imageData,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (category != null) 'category': category,
      };

      final response = await _apiClient.callFunction(
        functionName: 'create-group',
        body: body,
      );

      debugPrint('[GroupService] ✅ グループ作成成功');
      return GroupModel.fromJson(response['group'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[GroupService] ❌ グループ作成エラー: $e');
      rethrow;
    }
  }

  /// ユーザーのグループ一覧取得
  Future<List<GroupModel>> getUserGroups({required String userId}) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'get-user-groups',
        body: {'user_id': userId},
      );

      final groupsList = response['groups'] as List<dynamic>;
      final groups = groupsList
          .map((json) => GroupModel.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('[GroupService] ✅ グループ一覧取得成功: ${groups.length}件');
      return groups;
    } catch (e) {
      debugPrint('[GroupService] ❌ グループ一覧取得エラー: $e');
      rethrow;
    }
  }

  /// グループ詳細取得
  Future<GroupModel> getGroupDetail({required String groupId}) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'get-group-detail',
        body: {'group_id': groupId},
      );

      debugPrint('[GroupService] ✅ グループ詳細取得成功');
      return GroupModel.fromJson(response['group'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[GroupService] ❌ グループ詳細取得エラー: $e');
      rethrow;
    }
  }

  /// グループメンバー追加
  Future<void> addGroupMember({
    required String groupId,
    required String userId,
    required String newMemberUserId,
  }) async {
    try {
      await _apiClient.callFunction(
        functionName: 'add-group-member',
        body: {
          'group_id': groupId,
          'user_id': userId,
          'new_member_user_id': newMemberUserId,
        },
      );

      debugPrint('[GroupService] ✅ メンバー追加成功');
    } catch (e) {
      debugPrint('[GroupService] ❌ メンバー追加エラー: $e');
      rethrow;
    }
  }

  /// グループメンバー削除
  Future<void> removeGroupMember({
    required String groupId,
    required String userId,
    required String targetUserId,
  }) async {
    try {
      await _apiClient.callFunction(
        functionName: 'remove-group-member',
        body: {
          'group_id': groupId,
          'user_id': userId,
          'target_user_id': targetUserId,
        },
      );

      debugPrint('[GroupService] ✅ メンバー削除成功');
    } catch (e) {
      debugPrint('[GroupService] ❌ メンバー削除エラー: $e');
      rethrow;
    }
  }

  /// グループ情報更新
  Future<GroupModel> updateGroup({
    required String groupId,
    required String userId,
    required String groupName,
    String? imageData,
    String? description,
    String? category,
  }) async {
    try {
      final body = {
        'group_id': groupId,
        'user_id': userId,
        'name': groupName,
        if (imageData != null) 'image_data': imageData,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (category != null) 'category': category,
      };

      final response = await _apiClient.callFunction(
        functionName: 'update-group',
        body: body,
      );

      debugPrint('[GroupService] ✅ グループ更新成功');
      return GroupModel.fromJson(response['group'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[GroupService] ❌ グループ更新エラー: $e');
      rethrow;
    }
  }

  /// グループ削除
  Future<void> deleteGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      await _apiClient.callFunction(
        functionName: 'delete-group',
        body: {'group_id': groupId, 'user_id': userId},
      );

      debugPrint('[GroupService] ✅ グループ削除成功');
    } catch (e) {
      debugPrint('[GroupService] ❌ グループ削除エラー: $e');
      rethrow;
    }
  }
}
