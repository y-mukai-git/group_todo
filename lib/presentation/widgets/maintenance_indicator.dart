import 'package:flutter/material.dart';
import '../../core/utils/api_client.dart';

/// メンテナンス中インジケーター
/// 管理者がメンテナンス中にアプリを利用している際に表示
class MaintenanceIndicator extends StatelessWidget {
  const MaintenanceIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient();

    // 管理者かつメンテナンス中の場合のみ表示
    if (!apiClient.isAdmin || !apiClient.isMaintenance) {
      return const SizedBox.shrink();
    }

    return Tooltip(
      message: 'メンテナンス中',
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.build,
          color: Colors.orange,
          size: 20,
        ),
      ),
    );
  }
}
