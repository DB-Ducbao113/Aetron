import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:flutter/material.dart';

enum BadgeTier {
  bronze,
  silver,
  gold,
  quantum;

  String label(AppLanguage lang) {
    switch (this) {
      case BadgeTier.bronze:
        return lang == AppLanguage.vi ? 'Đồng' : 'Bronze';
      case BadgeTier.silver:
        return lang == AppLanguage.vi ? 'Bạc' : 'Silver';
      case BadgeTier.gold:
        return lang == AppLanguage.vi ? 'Vàng' : 'Gold';
      case BadgeTier.quantum:
        return lang == AppLanguage.vi ? 'Quantum' : 'Quantum';
    }
  }

  Color get primaryColor {
    switch (this) {
      case BadgeTier.bronze:
        return const Color(0xFFFF9F43);
      case BadgeTier.silver:
        return const Color(0xFFE0E6ED);
      case BadgeTier.gold:
        return const Color(0xFFFFBA20);
      case BadgeTier.quantum:
        return const Color(0xFFA8DCE7);
    }
  }

  Color get secondaryColor {
    switch (this) {
      case BadgeTier.bronze:
        return const Color(0xFFD35400);
      case BadgeTier.silver:
        return const Color(0xFF94A3B8);
      case BadgeTier.gold:
        return const Color(0xFFE67E22);
      case BadgeTier.quantum:
        return const Color(0xFFA55EEA);
    }
  }

  Color get glowColor {
    switch (this) {
      case BadgeTier.bronze:
        return const Color(0xFFFF9F43).withValues(alpha: 0.35);
      case BadgeTier.silver:
        return const Color(0xFFE0E6ED).withValues(alpha: 0.30);
      case BadgeTier.gold:
        return const Color(0xFFFFBA20).withValues(alpha: 0.40);
      case BadgeTier.quantum:
        return const Color(0xFFA8DCE7).withValues(alpha: 0.45);
    }
  }

  IconData get tierIcon {
    switch (this) {
      case BadgeTier.bronze:
        return Icons.military_tech_outlined;
      case BadgeTier.silver:
        return Icons.shield_outlined;
      case BadgeTier.gold:
        return Icons.emoji_events_rounded;
      case BadgeTier.quantum:
        return Icons.diamond_rounded;
    }
  }
}

enum BadgeCategory {
  all,
  milestone,
  streak,
  distance,
  speed,
  special;

  String label(AppLanguage lang) {
    switch (this) {
      case BadgeCategory.all:
        return lang == AppLanguage.vi ? 'Tất cả' : 'All';
      case BadgeCategory.milestone:
        return lang == AppLanguage.vi ? 'Cột mốc' : 'Milestones';
      case BadgeCategory.streak:
        return lang == AppLanguage.vi ? 'Chuỗi ngày' : 'Streak';
      case BadgeCategory.distance:
        return lang == AppLanguage.vi ? 'Cự ly' : 'Distance';
      case BadgeCategory.speed:
        return lang == AppLanguage.vi ? 'Hiệu suất' : 'Speed';
      case BadgeCategory.special:
        return lang == AppLanguage.vi ? 'Đặc biệt' : 'Special';
    }
  }

  IconData get icon {
    switch (this) {
      case BadgeCategory.all:
        return Icons.grid_view_rounded;
      case BadgeCategory.milestone:
        return Icons.flag_rounded;
      case BadgeCategory.streak:
        return Icons.local_fire_department_rounded;
      case BadgeCategory.distance:
        return Icons.route_rounded;
      case BadgeCategory.speed:
        return Icons.speed_rounded;
      case BadgeCategory.special:
        return Icons.auto_awesome_rounded;
    }
  }
}

class AchievementBadge {
  final String id;
  final BadgeTier tier;
  final BadgeCategory category;
  final String titleVi;
  final String titleEn;
  final String descriptionVi;
  final String descriptionEn;
  final String quoteVi;
  final String quoteEn;
  final IconData icon;
  final double currentValue;
  final double targetValue;
  final String unitVi;
  final String unitEn;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const AchievementBadge({
    required this.id,
    required this.tier,
    required this.category,
    required this.titleVi,
    required this.titleEn,
    required this.descriptionVi,
    required this.descriptionEn,
    required this.quoteVi,
    required this.quoteEn,
    required this.icon,
    required this.currentValue,
    required this.targetValue,
    required this.unitVi,
    required this.unitEn,
    required this.isUnlocked,
    this.unlockedAt,
  });

  String title(AppLanguage lang) => lang == AppLanguage.vi ? titleVi : titleEn;
  String description(AppLanguage lang) =>
      lang == AppLanguage.vi ? descriptionVi : descriptionEn;
  String quote(AppLanguage lang) => lang == AppLanguage.vi ? quoteVi : quoteEn;
  String unit(AppLanguage lang) => lang == AppLanguage.vi ? unitVi : unitEn;

  double get progress {
    if (targetValue <= 0) return 1.0;
    final ratio = currentValue / targetValue;
    return ratio.clamp(0.0, 1.0);
  }

  int get progressPercent => (progress * 100).round();

  String formattedProgress(AppLanguage lang) {
    final curFormatted = currentValue % 1 == 0
        ? currentValue.toInt().toString()
        : currentValue.toStringAsFixed(1);
    final tarFormatted = targetValue % 1 == 0
        ? targetValue.toInt().toString()
        : targetValue.toStringAsFixed(1);
    final u = unit(lang);
    return '$curFormatted / $tarFormatted $u';
  }

  String remainingText(AppLanguage lang) {
    if (isUnlocked) {
      return lang == AppLanguage.vi ? 'Đã đạt được' : 'Unlocked';
    }
    final remaining = (targetValue - currentValue).clamp(0.0, targetValue);
    final remFormatted = remaining % 1 == 0
        ? remaining.toInt().toString()
        : remaining.toStringAsFixed(1);
    final u = unit(lang);
    return lang == AppLanguage.vi
        ? 'Còn $remFormatted $u'
        : '$remFormatted $u left';
  }
}
