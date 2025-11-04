import 'package:flutter/material.dart';

/// コンテンツポリシー画面
class ContentPolicyScreen extends StatelessWidget {
  const ContentPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.amber[700], size: 24),
            const SizedBox(width: 8),
            const Text('入力における注意事項'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 禁止事項（黄色背景）
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber[300]!, width: 2),
              ),
              child: _buildSection(
                context: context,
                title: '禁止事項',
                description: '以下の内容の入力はお控えください。',
                examples: ['個人情報', '差別的な表現', '暴力的な表現', '性的な表現', '誹謗中傷'],
              ),
            ),

            const SizedBox(height: 24),

            // 違反時の対応
            Text(
              '違反時の対応',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '上記のコンテンツを入力しようとした場合、保存がブロックされます。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required String description,
    required List<String> examples,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // タイトル
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        // 説明
        Text(description, style: Theme.of(context).textTheme.bodyMedium),

        // 例
        if (examples.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...examples.map(
            (example) => Padding(
              padding: const EdgeInsets.only(left: 8, top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_rounded,
                    size: 18,
                    color: Colors.amber[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      example,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
