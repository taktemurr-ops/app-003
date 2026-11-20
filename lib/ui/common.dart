import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hydration_universe/l10n/app_localizations.dart';
import '../beverages.dart';
import '../hydration_store.dart';
import '../settings.dart';
import '../stats.dart';

String localeTag(BuildContext context) => Localizations.localeOf(context).toLanguageTag();

String beverageName(AppLocalizations l, Beverage b) {
  final custom = b.customName;
  if (custom != null) return custom;
  return beverageNameById(l, b.id);
}

String entryBeverageName(AppLocalizations l, HydrationStore store, String id) {
  final b = store.findBeverage(id);
  return b == null ? beverageNameById(l, id) : beverageName(l, b);
}

String beverageNameById(AppLocalizations l, String id) => switch (id) {
      'water' => l.bevWater,
      'sparkling' => l.bevSparkling,
      'herbalTea' => l.bevHerbalTea,
      'tea' => l.bevTea,
      'coffee' => l.bevCoffee,
      'milk' => l.bevMilk,
      'juice' => l.bevJuice,
      'sportsDrink' => l.bevSportsDrink,
      'smoothie' => l.bevSmoothie,
      'soup' => l.bevSoup,
      _ => l.bevCustom,
    };

/// Constant icons only (non-constant IconData breaks release icon tree-shaking).
IconData beverageIcon(String id) => switch (id) {
      'water' => Icons.water_drop,
      'sparkling' => Icons.bubble_chart,
      'herbalTea' => Icons.eco,
      'tea' => Icons.emoji_food_beverage,
      'coffee' => Icons.coffee,
      'milk' => Icons.local_drink,
      'juice' => Icons.local_bar,
      'sportsDrink' => Icons.fitness_center,
      'smoothie' => Icons.blender,
      'soup' => Icons.soup_kitchen,
      _ => Icons.local_cafe,
    };

String climateLabel(AppLocalizations l, Climate c) => switch (c) {
      Climate.cool => l.climateCool,
      Climate.temperate => l.climateTemperate,
      Climate.hot => l.climateHot,
      Climate.veryHot => l.climateVeryHot,
    };

String lifeStageLabel(AppLocalizations l, LifeStage s) => switch (s) {
      LifeStage.standard => l.lifeStandard,
      LifeStage.pregnant => l.lifePregnant,
      LifeStage.breastfeeding => l.lifeBreastfeeding,
    };

String unitLabel(AppLocalizations l, VolumeUnit u) => switch (u) {
      VolumeUnit.ml => l.unitMl,
      VolumeUnit.usOz => l.unitUsOz,
      VolumeUnit.ukOz => l.unitUkOz,
    };

({String title, String body, IconData icon}) achievementText(AppLocalizations l, Achievement a) => switch (a) {
      Achievement.firstDrink => (title: l.achFirstDrink, body: l.achFirstDrinkBody, icon: Icons.water_drop),
      Achievement.firstGoal => (title: l.achFirstGoal, body: l.achFirstGoalBody, icon: Icons.flag),
      Achievement.streak3 => (title: l.achStreak3, body: l.achStreak3Body, icon: Icons.local_fire_department),
      Achievement.streak7 => (title: l.achStreak7, body: l.achStreak7Body, icon: Icons.whatshot),
      Achievement.streak30 => (title: l.achStreak30, body: l.achStreak30Body, icon: Icons.military_tech),
      Achievement.days30 => (title: l.achDays30, body: l.achDays30Body, icon: Icons.calendar_month),
      Achievement.liters100 => (title: l.achLiters100, body: l.achLiters100Body, icon: Icons.waves),
    };

String minutesToTime(BuildContext context, int minutes) =>
    MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));

/// Circular daily progress ring.
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.progress, required this.child, this.size = 200});
  final double progress;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(progress.clamp(0.0, 1.0), scheme.primary, scheme.surfaceContainerHighest),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color, this.track);
  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, base);
    if (progress > 0) canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * progress, false, fill);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color || old.track != track;
}

/// Simple bar chart with a goal line; bars that reach the goal are highlighted.
class GoalBarChart extends StatelessWidget {
  const GoalBarChart({super.key, required this.values, required this.goal, required this.semanticLabel});
  final List<int> values;
  final int goal;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel,
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: CustomPaint(painter: _BarPainter(values, goal, scheme.primary, scheme.primaryContainer, scheme.error)),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.values, this.goal, this.done, this.partial, this.goalLine);
  final List<int> values;
  final int goal;
  final Color done;
  final Color partial;
  final Color goalLine;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxValue = math.max(goal * 1.2, values.fold<int>(0, math.max).toDouble());
    final slot = size.width / values.length;
    final barWidth = math.max(2.0, slot * 0.65);
    for (var i = 0; i < values.length; i++) {
      final h = size.height * values[i] / maxValue;
      final paint = Paint()..color = values[i] >= goal ? done : partial;
      final left = i * slot + (slot - barWidth) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, size.height - h, barWidth, h), const Radius.circular(3)),
        paint,
      );
    }
    final y = size.height - size.height * goal / maxValue;
    final line = Paint()
      ..color = goalLine
      ..strokeWidth = 1.5;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, size.width), y), line);
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.values != values || old.goal != goal;
}
