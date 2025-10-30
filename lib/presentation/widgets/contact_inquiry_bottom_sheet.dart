import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../data/models/inquiry_type.dart';
import '../../data/models/user_model.dart';
import '../../services/contact_service.dart';
import '../../services/error_log_service.dart';
import 'error_dialog.dart';

/// お問い合わせボトムシート
class ContactInquiryBottomSheet extends StatefulWidget {
  final UserModel user;

  const ContactInquiryBottomSheet({super.key, required this.user});

  @override
  State<ContactInquiryBottomSheet> createState() =>
      _ContactInquiryBottomSheetState();
}

class _ContactInquiryBottomSheetState extends State<ContactInquiryBottomSheet> {
  final TextEditingController _messageController = TextEditingController();
  InquiryType _selectedType = InquiryType.bugReport;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  /// お問い合わせ種別選択ピッカー表示
  Future<void> _showTypePicker() async {
    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 250,
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              // ヘッダー
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('キャンセル'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('完了'),
                    ),
                  ],
                ),
              ),
              // ピッカー
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 40,
                  scrollController: FixedExtentScrollController(
                    initialItem: InquiryType.values.indexOf(_selectedType),
                  ),
                  onSelectedItemChanged: (int index) {
                    setState(() {
                      _selectedType = InquiryType.values[index];
                    });
                  },
                  children: InquiryType.values
                      .map((type) => Center(child: Text(type.displayName)))
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// お問い合わせ送信
  Future<void> _submitInquiry() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('お問い合わせ内容を入力してください'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ContactService().submitInquiry(
        userId: widget.user.id,
        type: _selectedType,
        message: message,
      );

      if (!mounted) return;

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('お問い合わせを送信しました'), backgroundColor: Colors.green),
      );
    } catch (e, stackTrace) {
      debugPrint('[ContactInquiryBottomSheet] ❌ お問い合わせ送信エラー: $e');

      // エラーログ記録
      final errorLog = await ErrorLogService().logError(
        userId: widget.user.id,
        errorType: 'お問い合わせ送信エラー',
        errorMessage: e.toString(),
        stackTrace: stackTrace.toString(),
        screenName: 'お問い合わせ',
      );

      // エラーダイアログ表示
      if (!mounted) return;
      await ErrorDialog.show(
        context: context,
        errorId: errorLog.id,
        errorMessage: 'お問い合わせの送信に失敗しました',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTap: () {
            // キーボードを閉じる
            FocusScope.of(context).unfocus();
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // ヘッダー
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.contact_support,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'お問い合わせ',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          if (!mounted) return;
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // コンテンツ
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      // お問い合わせ種別選択
                      Text(
                        'お問い合わせ種別',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _showTypePicker,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedType.displayName,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              Icon(
                                Icons.arrow_drop_down,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // お問い合わせ内容入力
                      Text(
                        'お問い合わせ内容',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _messageController,
                        maxLines: 8,
                        maxLength: 1000,
                        decoration: InputDecoration(
                          hintText: 'お問い合わせ内容を入力してください',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 送信ボタン
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isSubmitting ? null : _submitInquiry,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send),
                          label: Text(_isSubmitting ? '送信中...' : '送信'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
      },
    );
  }
}
