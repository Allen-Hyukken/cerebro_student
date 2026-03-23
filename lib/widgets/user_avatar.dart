import 'package:flutter/material.dart';
import 'package:quiz_app/services/api_service.dart';
import 'package:quiz_app/services/xp_service.dart';
import 'package:quiz_app/theme/app_theme.dart';

/// Shared avatar widget — shows emoji avatar or initials fallback
/// Used in drawer, leaderboard, profile, etc.
class UserAvatar extends StatefulWidget {
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
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  int _avatarIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final idx = await XpService().getAvatarIndex(ApiService.userId ?? 0);
    if (mounted) setState(() => _avatarIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    final emoji    = XpService.avatarEmojis[_avatarIndex];
    final fontSize = widget.size * 0.48;

    return Container(
      width: widget.size, height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.15),
        border: Border.all(
            color: widget.borderColor ?? AppColors.primary,
            width: widget.borderWidth),
      ),
      child: Center(child: Text(emoji, style: TextStyle(fontSize: fontSize))),
    );
  }
}

/// Static version for leaderboard rows (uses a known userId + name)
class PlayerAvatar extends StatefulWidget {
  final int userId;
  final String name;
  final double size;

  const PlayerAvatar({
    super.key,
    required this.userId,
    required this.name,
    this.size = 42,
  });

  @override
  State<PlayerAvatar> createState() => _PlayerAvatarState();
}

class _PlayerAvatarState extends State<PlayerAvatar> {
  int _avatarIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final idx = await XpService().getAvatarIndex(widget.userId);
    if (mounted) setState(() => _avatarIndex = idx);
  }

  String get _initials {
    final parts = widget.name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }

  Color get _color {
    final colors = [AppColors.primary, AppColors.correct, AppColors.wrong,
      Colors.orange, Colors.purple, Colors.teal, Colors.indigo];
    return colors[widget.userId % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    // If user has customized avatar (index > 0), show emoji
    // Otherwise show colored initials
    if (_avatarIndex > 0) {
      final emoji = XpService.avatarEmojis[_avatarIndex];
      return Container(
        width: widget.size, height: widget.size,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _color.withValues(alpha: 0.15),
            border: Border.all(color: _color.withValues(alpha: 0.4))),
        child: Center(child: Text(emoji,
            style: TextStyle(fontSize: widget.size * 0.48))),
      );
    }

    // Default: colored initials
    return Container(
      width: widget.size, height: widget.size,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _color,
          boxShadow: [BoxShadow(color: _color.withValues(alpha: 0.3), blurRadius: 6)]),
      child: Center(child: Text(_initials,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold,
              fontSize: widget.size * 0.35))),
    );
  }
}