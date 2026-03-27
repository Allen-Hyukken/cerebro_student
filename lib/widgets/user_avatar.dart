import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_app/providers/xp_provider.dart';
import 'package:quiz_app/services/xp_service.dart';
import 'package:quiz_app/theme/app_theme.dart';

// ── Current-user avatar ───────────────────────────────────────────────────────

/// Shows the logged-in user's emoji avatar (driven by [xpProvider]).
class UserAvatar extends ConsumerWidget {
  final double size;
  final Color? borderColor;
  final double borderWidth;

  const UserAvatar({
    super.key,
    this.size = 48,
    this.borderColor,
    this.borderWidth = 2,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final xpState = ref.watch(xpProvider);
    final emoji   = xpState.emoji;

    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.15),
        border: Border.all(
          color: borderColor ?? AppColors.primary,
          width: borderWidth,
        ),
      ),
      child: Center(
        child: Text(emoji, style: TextStyle(fontSize: size * 0.48)),
      ),
    );
  }
}

// ── Arbitrary-player avatar (used in leaderboard rows) ───────────────────────

/// Shows emoji if the player has a custom avatar, otherwise coloured initials.
/// Uses [playerAvatarProvider] (auto-dispose family) to load per-userId.
class PlayerAvatar extends ConsumerWidget {
  final int    userId;
  final String name;
  final double size;

  const PlayerAvatar({
    super.key,
    required this.userId,
    required this.name,
    this.size = 42,
  });

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }

  Color get _color {
    const colors = [
      AppColors.primary, AppColors.correct, AppColors.wrong,
      Colors.orange,     Colors.purple,     Colors.teal,     Colors.indigo,
    ];
    return colors[userId % colors.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarAsync = ref.watch(playerAvatarProvider(userId));
    final avatarIndex = avatarAsync.valueOrNull ?? 0;

    if (avatarIndex > 0) {
      final emoji = XpService.avatarEmojis[avatarIndex];
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _color.withValues(alpha: 0.15),
          border: Border.all(color: _color.withValues(alpha: 0.4)),
        ),
        child: Center(
          child: Text(emoji, style: TextStyle(fontSize: size * 0.48)),
        ),
      );
    }

    // Default: coloured initials
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _color,
        boxShadow: [BoxShadow(
          color: _color.withValues(alpha: 0.3), blurRadius: 6,
        )],
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold,
            fontSize: size * 0.35,
          ),
        ),
      ),
    );
  }
}