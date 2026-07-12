import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/services/tts_service.dart';
import 'package:kana_trainer/core/theme/app_theme.dart';
import 'shake.dart';

/// 發音按鈕（設計稿 2c：深靛藍方塊 + 金黃喇叭）。
class SpeakButton extends ConsumerWidget {
  final String text;
  final double size;

  const SpeakButton({super.key, required this.text, this.size = 38});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppColors.indigo,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: () => ref.read(ttsProvider).speak(text),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(Icons.volume_up, color: AppColors.gold, size: size * .5),
        ),
      ),
    );
  }
}

/// 深靛藍頂部：返回、標題、連對火焰、session 分數、5 段進度。
/// 假名與單字練習頁共用。
class PracticeHeader extends StatelessWidget {
  final String title;
  final int streak;
  final int sessionCorrect;
  final int sessionTotal;

  const PracticeHeader({
    super.key,
    required this.title,
    required this.streak,
    required this.sessionCorrect,
    required this.sessionTotal,
  });

  @override
  Widget build(BuildContext context) {
    final filled = sessionTotal % 5;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.indigo,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(6, 0, 18, 22),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 20),
                ),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '🔥 $streak',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  '$sessionCorrect/$sessionTotal',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  for (var i = 0; i < 5; i++) ...[
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 5,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: i < (filled == 0 && sessionTotal > 0
                                  ? 5
                                  : filled)
                              ? AppColors.gold
                              : Colors.white24,
                        ),
                      ),
                    ),
                    if (i < 4) const SizedBox(width: 5),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 選項按鈕狀態。
enum OptionState { idle, correct, wrong, dimmed }

/// 4 選 1 選項按鈕：白底靛藍框，答對綠✓、答錯紅✕晃動、其餘淡化。
class OptionButton extends StatelessWidget {
  final String label;
  final OptionState state;
  final VoidCallback? onTap;
  final double fontSize;

  const OptionButton({
    super.key,
    required this.label,
    required this.state,
    required this.onTap,
    this.fontSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border, icon) = switch (state) {
      OptionState.idle => (
          Colors.white,
          AppColors.indigo,
          AppColors.indigo,
          null
        ),
      OptionState.correct => (
          AppColors.green,
          Colors.white,
          AppColors.green,
          '✓'
        ),
      OptionState.wrong => (AppColors.red, Colors.white, AppColors.red, '✕'),
      OptionState.dimmed => (
          Colors.white,
          AppColors.indigo,
          AppColors.indigo,
          null
        ),
    };

    return Shake(
      active: state == OptionState.wrong,
      child: AnimatedOpacity(
        opacity: state == OptionState.dimmed ? 0.35 : 1,
        duration: const Duration(milliseconds: 200),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(color: border, width: 3),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w800,
                        color: fg,
                      ),
                    ),
                  ),
                  if (icon != null)
                    Positioned(
                      top: 4,
                      right: 8,
                      child: Text(
                        icon,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: fg,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 底部反饋橫幅：綠答對 / 紅答錯 + 下一題（可選再試一次）。
class FeedbackBanner extends StatelessWidget {
  final bool correct;
  final String subtitle;
  final bool showRetry;
  final VoidCallback? onRetry;
  final VoidCallback onNext;

  const FeedbackBanner({
    super.key,
    required this.correct,
    required this.subtitle,
    this.showRetry = false,
    this.onRetry,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
      decoration: BoxDecoration(
        color: correct ? AppColors.green : AppColors.red,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        boxShadow: const [
          BoxShadow(color: Color(0x4022254A), offset: Offset(6, 6)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  correct ? '答對了！' : '再試一次，你可以的！',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (showRetry && onRetry != null) ...[
            BannerButton(label: '再試一次', onTap: onRetry!),
            const SizedBox(width: 8),
          ],
          BannerButton(label: '下一題', onTap: onNext),
        ],
      ),
    );
  }
}

class BannerButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const BannerButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white24,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
