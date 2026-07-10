import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// 各 tab 頂部深靛藍 header（2c 設計）。
class TabHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const TabHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.indigo,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 8, 20),
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// 區塊標題。
class SectionTitle extends StatelessWidget {
  final String text;

  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: AppColors.indigo,
      ),
    );
  }
}

/// 通用入口卡：色塊 icon + 標籤 + 可選 badge。
class EntryCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String? badge;
  final bool enabled;
  final VoidCallback onTap;

  const EntryCard({
    super.key,
    required this.icon,
    required this.iconBg,
    this.iconColor = Colors.white,
    required this.label,
    this.badge,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: AppColors.indigo, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: iconColor, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.indigo,
                    ),
                  ),
                ),
                if (badge != null)
                  Badge(
                    label: Text(badge!),
                    backgroundColor: AppColors.gold,
                    textColor: AppColors.indigo,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 入口卡 2 欄格。
class EntryGrid extends StatelessWidget {
  final List<Widget> children;

  const EntryGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.9,
      children: children,
    );
  }
}
