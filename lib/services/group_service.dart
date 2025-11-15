import 'package:flutter/foundation.dart';
import '../core/utils/api_client.dart';
import '../data/models/group_model.dart';
import '../data/models/group_invitation.dart';

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

      if (response['success'] != true) {
        final errorMessage = response['error'] as String? ?? 'グループの作成に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }

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

      if (response['success'] != true) {
        final errorMessage = response['error'] as String? ?? 'グループ一覧の取得に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }

      final groupsList = response['groups'] as List<dynamic>;
      final groups = groupsList
          .map((json) => GroupModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return groups;
    } catch (e) {
      debugPrint('[GroupService] ❌ グループ一覧取得エラー: $e');
      rethrow;
    }
  }

  /// グループ詳細取得
  Future<GroupModel> getGroupDetail({
    required String groupId,
    required String userId,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'get-group-detail',
        body: {'group_id': groupId, 'user_id': userId},
      );

      if (response['success'] != true) {
        final errorMessage = response['error'] as String? ?? 'グループ詳細の取得に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }

      return GroupModel.fromJson(response['group'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[GroupService] ❌ グループ詳細取得エラー: $e');
      rethrow;
    }
  }

  /// グループメンバー一覧取得
  Future<Map<String, dynamic>> getGroupMembers({
    required String groupId,
    required String requesterId,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'get-group-members',
        body: {'group_id': groupId, 'requester_id': requesterId},
      );

      if (response['success'] != true) {
        final errorMessage = response['error'] as String? ?? 'メンバー一覧の取得に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }

      return response;
    } catch (e) {
      debugPrint('[GroupService] ❌ メンバー一覧取得エラー: $e');
      rethrow;
    }
  }

  /// グループメンバー追加
  Future<void> addGroupMember({
    required String groupId,
    required String displayId,
    required String inviterId,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'add-group-member',
        body: {
          'group_id': groupId,
          'display_id': displayId,
          'inviter_id': inviterId,
        },
      );

      if (response['success'] != true) {
        final errorMessage = response['error'] as String? ?? 'メンバーの追加に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }
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
      final response = await _apiClient.callFunction(
        functionName: 'remove-group-member',
        body: {
          'group_id': groupId,
          'requester_id': userId,
          'target_user_id': targetUserId,
        },
      );

      if (response['success'] != true) {
        final errorMessage = response['error'] as String? ?? 'メンバーの削除に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }
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

      if (response['success'] != true) {
        final errorMessage = response['error'] as String? ?? 'グループの更新に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }

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
      final response = await _apiClient.callFunction(
        functionName: 'delete-group',
        body: {'group_id': groupId, 'user_id': userId},
      );

      if (response['success'] != true) {
        final errorMessage = response['error'] as String? ?? 'グループの削除に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }
    } catch (e) {
      debugPrint('[GroupService] ❌ グループ削除エラー: $e');
      rethrow;
    }
  }

  /// グループ並び順更新
  Future<void> updateGroupOrder({
    required String userId,
    required List<Map<String, dynamic>> groupOrders,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'update-group-order',
        body: {'user_id': userId, 'group_orders': groupOrders},
      );

      if (response['success'] != true) {
        final errorMessage =
            response['error'] as String? ?? 'グループ並び順の更新に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }
    } catch (e) {
      debugPrint('[GroupService] ❌ グループ並び順更新エラー: $e');
      rethrow;
    }
  }

  // ==================== 招待関連メソッド ====================

  /// 招待前のユーザー情報取得・確認
  Future<Map<String, dynamic>> validateUserForInvitation({
    required String groupId,
    required String displayId,
    required String userId,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'validate-user-for-invitation',
        body: {'group_id': groupId, 'display_id': displayId, 'user_id': userId},
      );

      if (response['success'] != true) {
        final errorMessage =
            response['error'] as String? ?? 'ユーザー招待前の確認に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }

      return response;
    } catch (e) {
      debugPrint('[GroupService] ❌ ユーザー招待前確認エラー: $e');
      rethrow;
    }
  }

  /// ユーザーをグループに招待
  Future<GroupInvitationModel> inviteUserToGroup({
    required String groupId,
    required String inviterId,
    required String invitedUserId,
    required String invitedRole, // 'owner' or 'member'
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'invite-user',
        body: {
          'group_id': groupId,
          'inviter_id': inviterId,
          'invited_user_id': invitedUserId,
          'invited_role': invitedRole,
        },
      );

      if (response['success'] != true) {
        final errorMessage = response['error'] as String? ?? 'ユーザーの招待に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }

      return GroupInvitationModel.fromJson(
        response['invitation'] as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('[GroupService] ❌ ユーザー招待エラー: $e');
      rethrow;
    }
  }

  /// 自分宛の承認待ち招待一覧取得
  Future<List<Map<String, dynamic>>> getPendingInvitations({
    required String userId,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'get-pending-invitations',
        body: {'user_id': userId},
      );

      if (response['success'] != true) {
        final errorMessage =
            response['error'] as String? ?? '承認待ち招待一覧の取得に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }

      final invitationsList = response['invitations'] as List<dynamic>;
      return invitationsList
          .map((json) => json as Map<String, dynamic>)
          .toList();
    } catch (e) {
      debugPrint('[GroupService] ❌ 承認待ち招待一覧取得エラー: $e');
      rethrow;
    }
  }

  /// 招待を承認
  Future<void> acceptInvitation({
    required String invitationId,
    required String userId,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'accept-invitation',
        body: {'invitation_id': invitationId, 'user_id': userId},
      );

      if (response['success'] != true) {
        final errorMessage = response['error'] as String? ?? '招待の承認に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }
    } catch (e) {
      debugPrint('[GroupService] ❌ 招待承認エラー: $e');
      rethrow;
    }
  }

  /// 招待を却下
  Future<void> rejectInvitation({
    required String invitationId,
    required String userId,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'reject-invitation',
        body: {'invitation_id': invitationId, 'user_id': userId},
      );

      if (response['success'] != true) {
        final errorMessage = response['error'] as String? ?? '招待の却下に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }
    } catch (e) {
      debugPrint('[GroupService] ❌ 招待却下エラー: $e');
      rethrow;
    }
  }

  /// 招待をキャンセル
  Future<void> cancelInvitation({
    required String invitationId,
    required String userId,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'cancel-invitation',
        body: {'invitation_id': invitationId, 'user_id': userId},
      );

      if (response['success'] != true) {
        final errorMessage = response['error'] as String? ?? '招待のキャンセルに失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }
    } catch (e) {
      debugPrint('[GroupService] ❌ 招待キャンセルエラー: $e');
      rethrow;
    }
  }

  /// メンバーのロールを変更
  Future<void> changeMemberRole({
    required String groupId,
    required String targetUserId,
    required String newRole,
    required String requesterId,
  }) async {
    try {
      final response = await _apiClient.callFunction(
        functionName: 'change-member-role',
        body: {
          'group_id': groupId,
          'target_user_id': targetUserId,
          'new_role': newRole,
          'requester_id': requesterId,
        },
      );

      if (response['success'] != true) {
        final errorMessage =
            response['error'] as String? ?? 'メンバーロールの変更に失敗しました';
        throw ApiException(message: errorMessage, statusCode: 200);
      }
    } catch (e) {
      debugPrint('[GroupService] ❌ メンバーロール変更エラー: $e');
      rethrow;
    }
  }
}
