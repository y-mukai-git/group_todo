import 'package:flutter/material.dart';

/// コンテンツポリシー画面
class ContentPolicyScreen extends StatelessWidget {
  const ContentPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('コンテンツポリシー')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 禁止事項
            _buildSection(
              context: context,
              title: '禁止事項',
              description: '以下の内容の入力はお控えください。',
              examples: [
                '個人情報（メールアドレス、電話番号など）',
                '差別的な表現',
                '暴力的な表現',
                '性的な表現',
                '誹謗中傷',
              ],
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
              padding: const EdgeInsets.only(left: 16, top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•  ',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
