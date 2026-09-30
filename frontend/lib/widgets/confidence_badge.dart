import 'package:flutter/material.dart';

class ConfidenceBadge extends StatelessWidget {
  final double score; // 0.0 to 1.0
  final String band;  // HIGH, NEEDS_REVIEW, MANUAL_VERIFICATION
  final bool compact;

  const ConfidenceBadge({
    super.key,
    required this.score,
    required this.band,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    final pct = (score * 100).toInt();

    switch (band) {
      case "HIGH":
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        icon = Icons.verified_rounded;
        label = compact ? "$pct%" : "High Confidence ($pct%)";
        break;
      case "NEEDS_REVIEW":
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        icon = Icons.visibility_rounded;
        label = compact ? "$pct%" : "Needs Review ($pct%)";
        break;
      default: // MANUAL_VERIFICATION
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        icon = Icons.warning_amber_rounded;
        label = compact ? "$pct%" : "Manual Verification ($pct%)";
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
