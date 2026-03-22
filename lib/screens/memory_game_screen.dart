import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:quiz_app/theme/app_theme.dart';

// ── Card model ────────────────────────────────────────────────────────────────
class _Card {
  final int id;
  final String emoji;
  bool isFlipped = false;
  bool isMatched = false;
  _Card({required this.id, required this.emoji});
}

class MemoryGameScreen extends StatefulWidget {
  const MemoryGameScreen({super.key});

  @override
  State<MemoryGameScreen> createState() => _MemoryGameScreenState();
}

class _MemoryGameScreenState extends State<MemoryGameScreen>
    with TickerProviderStateMixin {

  // ── Game config ───────────────────────────────────────────────────────────
  static const List<String> _emojis = [
    '🧠', '📚', '✏️', '🎯', '🏆', '💡',
    '🔬', '🎨', '🎵', '🌟', '🚀', '💎',
    '🦊', '🐼', '🌈', '⚡',
  ];

  int _gridSize   = 4; // 4x4
  int _moves      = 0;
  int _matches    = 0;
  int _seconds    = 0;
  bool _gameOver  = false;
  bool _canFlip   = true;

  List<_Card> _cards     = [];
  List<int>   _flipped   = []; // indices of currently flipped (unmatched) cards
  Timer?      _timer;
  bool        _isPreview = false; // true during the 1s preview at start

  // Flip animation controllers per card
  late List<AnimationController> _flipControllers;
  late List<Animation<double>>   _flipAnims;

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _flipControllers) c.dispose();
    super.dispose();
  }

  // ── Game logic ────────────────────────────────────────────────────────────

  void _startGame() {
    _timer?.cancel();
    final pairCount = (_gridSize * _gridSize) ~/ 2;
    final shuffled  = List<String>.from(_emojis)..shuffle(Random());
    final emojis    = shuffled.take(pairCount).toList();
    final all       = [...emojis, ...emojis]..shuffle(Random());

    _cards   = all.asMap().entries.map((e) => _Card(id: e.key, emoji: e.value)).toList();
    _flipped = [];
    _moves   = 0;
    _matches = 0;
    _seconds = 0;
    _gameOver = false;
    _canFlip  = true;

    _flipControllers = List.generate(_cards.length, (_) =>
        AnimationController(vsync: this, duration: const Duration(milliseconds: 400)));
    _flipAnims = _flipControllers.map((c) =>
        Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut))).toList();

    setState(() { _isPreview = true; _canFlip = false; });

    // Flip all cards face up for 1 second so player can preview
    for (int i = 0; i < _cards.length; i++) {
      _flipControllers[i].forward();
      _cards[i].isFlipped = true;
    }

    // After 1.5s flip all back and start game
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      for (int i = 0; i < _cards.length; i++) {
        _flipControllers[i].reverse();
        _cards[i].isFlipped = false;
      }
      setState(() { _isPreview = false; _canFlip = true; });

      // Start timer only after preview ends
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_gameOver && mounted) setState(() => _seconds++);
      });
    });
  }

  void _onTap(int index) {
    final card = _cards[index];
    if (!_canFlip || card.isFlipped || card.isMatched) return;
    if (_flipped.length >= 2) return;

    // Flip card
    _flipControllers[index].forward();
    setState(() {
      card.isFlipped = true;
      _flipped.add(index);
    });

    if (_flipped.length == 2) {
      _moves++;
      _canFlip = false;
      _checkMatch();
    }
  }

  void _checkMatch() {
    final a = _cards[_flipped[0]];
    final b = _cards[_flipped[1]];

    if (a.emoji == b.emoji) {
      // Match!
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        setState(() {
          a.isMatched = true;
          b.isMatched = true;
          _matches++;
          _flipped.clear();
          _canFlip = true;
        });
        if (_matches == (_gridSize * _gridSize) ~/ 2) {
          _timer?.cancel();
          setState(() => _gameOver = true);
          _showWinDialog();
        }
      });
    } else {
      // No match — flip back
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        _flipControllers[_flipped[0]].reverse();
        _flipControllers[_flipped[1]].reverse();
        setState(() {
          a.isFlipped = false;
          b.isFlipped = false;
          _flipped.clear();
          _canFlip = true;
        });
      });
    }
  }

  String get _timeStr {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  // ── Win dialog ────────────────────────────────────────────────────────────
  void _showWinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: TC.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🏆', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 12),
          Text('You Win!',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: TC.text(context))),
          const SizedBox(height: 8),
          Text('$_moves moves · $_timeStr',
              style: TextStyle(fontSize: 14, color: TC.subText(context))),
          const SizedBox(height: 8),
          // Star rating
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(3, (i) {
            final stars = _moves <= (_gridSize * _gridSize) ~/ 2 + 2 ? 3
                : _moves <= (_gridSize * _gridSize) ? 2 : 1;
            return Icon(i < stars ? Icons.star : Icons.star_border,
                color: const Color(0xFFFFD700), size: 32);
          })),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              child: const Text('Exit', style: TextStyle(color: AppColors.primary)),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () { Navigator.pop(ctx); _startGame(); },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              child: const Text('Play Again'),
            )),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TC.bg(context),
      body: SafeArea(
        child: Column(children: [

          // ── Top bar ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              IconButton(
                  icon: Icon(Icons.arrow_back, color: TC.text(context)),
                  onPressed: () => Navigator.pop(context)),
              Expanded(child: Text('Memory Game',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: TC.text(context)))),
              IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.primary),
                  onPressed: _startGame),
            ]),
          ),

          // ── Stats bar ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                  color: TC.surface(context),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8, offset: const Offset(0, 2))]),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _StatChip(icon: Icons.touch_app, label: 'Moves', value: '$_moves'),
                Container(width: 1, height: 30, color: TC.divider(context)),
                _StatChip(icon: Icons.favorite, label: 'Matched', value: '$_matches/${(_gridSize * _gridSize) ~/ 2}'),
                Container(width: 1, height: 30, color: TC.divider(context)),
                _StatChip(icon: Icons.timer, label: 'Time', value: _timeStr),
              ]),
            ),
          ),

          const SizedBox(height: 12),

          // ── Difficulty selector ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Grid: ', style: TextStyle(color: TC.subText(context), fontSize: 13)),
              ...[['2x2', 2], ['4x4', 4], ['6x6', 6]].map((d) {
                final size = d[1] as int;
                final isSelected = _gridSize == size;
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: GestureDetector(
                    onTap: () { setState(() => _gridSize = size); _startGame(); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : TC.card(context),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(d[0] as String,
                          style: TextStyle(
                              color: isSelected ? Colors.white : TC.subText(context),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13)),
                    ),
                  ),
                );
              }),
            ]),
          ),

          const SizedBox(height: 12),

          // ── Card grid with preview overlay ────────────────────────────
          Expanded(
            child: Stack(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _gridSize,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _cards.length,
                  itemBuilder: (_, i) => _CardWidget(
                    card:     _cards[i],
                    anim:     _flipAnims[i],
                    gridSize: _gridSize,
                    onTap:    () => _onTap(i),
                  ),
                ),
              ),

              // Preview banner at bottom of grid
              if (_isPreview)
                Positioned(
                  bottom: 16, left: 16, right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                        color: const Color(0xFF1A8A6E),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 12, offset: const Offset(0, 4))]),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.visibility, color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text('Memorize the cards!',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ]),
                  ),
                ),
            ]),
          ),

          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

// ── Card widget with flip animation ──────────────────────────────────────────
class _CardWidget extends StatelessWidget {
  final _Card card;
  final Animation<double> anim;
  final int gridSize;
  final VoidCallback onTap;

  const _CardWidget({
    required this.card,
    required this.anim,
    required this.gridSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = gridSize <= 2 ? 48.0 : gridSize <= 4 ? 28.0 : 18.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: anim,
        builder: (_, __) {
          final angle = anim.value * pi;
          final isFront = angle > pi / 2;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: card.isMatched
                    ? AppColors.correct.withValues(alpha: 0.15)
                    : isFront
                    ? TC.surface(context)
                    : AppColors.primary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: card.isMatched
                        ? AppColors.correct
                        : isFront
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : AppColors.darkCard,
                    width: card.isMatched ? 2 : 1),
                boxShadow: [BoxShadow(
                    color: card.isMatched
                        ? AppColors.correct.withValues(alpha: 0.2)
                        : AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Center(
                child: isFront
                    ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: Text(card.emoji, style: TextStyle(fontSize: fontSize)))
                    : card.isMatched
                    ? Text(card.emoji, style: TextStyle(fontSize: fontSize))
                    : _CardBack(gridSize: gridSize),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Card back design ─────────────────────────────────────────────────────────
class _CardBack extends StatelessWidget {
  final int gridSize;
  const _CardBack({required this.gridSize});

  @override
  Widget build(BuildContext context) {
    // Try to use logo asset, fallback to custom painted design
    return Stack(fit: StackFit.expand, children: [
      // Background gradient
      Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.darkCard],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)),
      ),
      // Pattern overlay
      CustomPaint(painter: _CardPatternPainter()),
      // Card image fills the back
      Positioned.fill(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/icons/card.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Icon(
                Icons.psychology,
                color: Colors.white.withValues(alpha: 0.9),
                size: gridSize <= 2 ? 52 : gridSize <= 4 ? 30 : 18),
          ),
        ),
      ),
    ]);
  }
}

// ── Card pattern painter ──────────────────────────────────────────────────────
class _CardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw diagonal lines pattern
    const spacing = 12.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
    }

    // Border glow
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(4, 4, size.width - 8, size.height - 8),
            const Radius.circular(8)),
        borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Stat chip ─────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _StatChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(children: [
    Row(children: [
      Icon(icon, color: AppColors.primary, size: 14),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: TC.subText(context))),
    ]),
    const SizedBox(height: 2),
    Text(value, style: TextStyle(
        fontSize: 16, fontWeight: FontWeight.bold, color: TC.text(context))),
  ]);
}