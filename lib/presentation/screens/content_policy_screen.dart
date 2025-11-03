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
            // 個人情報入力禁止
            _buildSection(
              context: context,
              icon: Icons.privacy_tip,
              iconColor: Colors.orange,
              title: '個人情報の入力禁止',
              description: '個人を特定できる情報の入力はお控えください。',
              examples: ['氏名、住所', 'メールアドレス', '電話番号', 'クレジットカード番号'],
            ),

            const SizedBox(height: 32),

            // 不適切な表現の禁止
            _buildSection(
              context: context,
              icon: Icons.block,
              iconColor: Colors.red,
              title: '不適切な表現の禁止',
              description: '以下のような表現の使用は禁止されています。',
              examples: ['差別的な表現', '暴力的な表現', '性的な表現', '誹謗中傷'],
            ),

            const SizedBox(height: 32),

            // 違反時の対応
            _buildSection(
              context: context,
              icon: Icons.warning,
              iconColor: Colors.deepOrange,
              title: '違反時の対応',
              description: '上記のコンテンツを入力しようとした場合、保存がブロックされます。',
              examples: [],
            ),

            const SizedBox(height: 32),

            // 注意事項
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade700,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'このアプリは家族や友人との情報共有を目的としています。'
                      '安全で快適な環境を維持するため、ご協力をお願いします。',
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required List<String> examples,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // タイトル
        Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 説明
        Text(description, style: Theme.of(context).textTheme.bodyLarge),

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
