// beast_mode/test/ai_overexertion_test.dart
//
// Unit tests for the AI Overexertion Detection logic.
// Tests all 3 threshold conditions with boundary values.
// Run with: flutter test

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────
// Pure Dart implementation of the AI threshold logic for testing.
// Mirrors the Cloud Function logic in functions/index.js
// ─────────────────────────────────────────────────────────────────

class OverexertionResult {
  final bool triggered;
  final List<String> reasons;
  final String severity;

  OverexertionResult({
    required this.triggered,
    required this.reasons,
    required this.severity,
  });
}

OverexertionResult evaluateOverexertion({
  required double todayIntensity,
  required double avgIntensity7Day,
  required double restGapHours,
  required String exerciseType,
  required int thisWeekCount,
  required int weeklyTarget,
}) {
  final reasons = <String>[];

  // Threshold 1: Intensity spike > 2.5 above 7-day rolling average
  final delta = todayIntensity - avgIntensity7Day;
  if (delta > 2.5) {
    reasons.add(
        'Your intensity today (${todayIntensity}/10) is ${delta.toStringAsFixed(1)} points '
        'above your 7-day average (${avgIntensity7Day.toStringAsFixed(1)}/10).');
  }

  // Threshold 2: Insufficient rest gap
  final minRest = exerciseType == 'cardio' ? 4.0 : 12.0;
  if (restGapHours < minRest) {
    reasons.add(
        'Only ${restGapHours.toStringAsFixed(1)} hours since your last workout — '
        '$exerciseType sessions need at least ${minRest.toInt()}h of recovery.');
  }

  // Threshold 3: Goal mismatch
  if (thisWeekCount >= weeklyTarget) {
    reasons.add(
        "You've already completed $thisWeekCount $exerciseType sessions this week — "
        'your goal is $weeklyTarget/week.');
  }

  final triggered = reasons.isNotEmpty;
  final severity = reasons.length >= 2 ? 'warning' : 'caution';

  return OverexertionResult(
      triggered: triggered, reasons: reasons, severity: severity);
}

// ─────────────────────────────────────────────────────────────────
void main() {
  group('AI Overexertion — Threshold 1: Intensity Spike', () {
    test('No flag when delta is exactly 2.5 (boundary — should NOT flag)', () {
      final result = evaluateOverexertion(
        todayIntensity: 7.5,
        avgIntensity7Day: 5.0,
        restGapHours: 24,
        exerciseType: 'strength',
        thisWeekCount: 2,
        weeklyTarget: 3,
      );
      expect(result.triggered, false);
      expect(result.reasons, isEmpty);
    });

    test('Flag when delta is 2.51 (just above boundary — should flag)', () {
      final result = evaluateOverexertion(
        todayIntensity: 7.51,
        avgIntensity7Day: 5.0,
        restGapHours: 24,
        exerciseType: 'strength',
        thisWeekCount: 2,
        weeklyTarget: 3,
      );
      expect(result.triggered, true);
      expect(result.reasons.length, 1);
      expect(result.severity, 'caution');
    });

    test('No flag when today intensity is below 7-day average', () {
      final result = evaluateOverexertion(
        todayIntensity: 4.0,
        avgIntensity7Day: 7.0,
        restGapHours: 24,
        exerciseType: 'strength',
        thisWeekCount: 1,
        weeklyTarget: 3,
      );
      expect(result.triggered, false);
    });
  });

  group('AI Overexertion — Threshold 2: Rest Gap', () {
    test('Strength: flag when rest gap is under 12h', () {
      final result = evaluateOverexertion(
        todayIntensity: 5.0,
        avgIntensity7Day: 5.0,
        restGapHours: 11.9,
        exerciseType: 'strength',
        thisWeekCount: 1,
        weeklyTarget: 3,
      );
      expect(result.triggered, true);
      expect(result.reasons.any((r) => r.contains('12h')), true);
    });

    test('Strength: no flag when rest gap is exactly 12h (boundary)', () {
      final result = evaluateOverexertion(
        todayIntensity: 5.0,
        avgIntensity7Day: 5.0,
        restGapHours: 12.0,
        exerciseType: 'strength',
        thisWeekCount: 1,
        weeklyTarget: 3,
      );
      expect(result.triggered, false);
    });

    test('Cardio: flag when rest gap is under 4h', () {
      final result = evaluateOverexertion(
        todayIntensity: 5.0,
        avgIntensity7Day: 5.0,
        restGapHours: 3.5,
        exerciseType: 'cardio',
        thisWeekCount: 1,
        weeklyTarget: 2,
      );
      expect(result.triggered, true);
      expect(result.reasons.any((r) => r.contains('4h')), true);
    });

    test('Cardio: no flag when rest gap is exactly 4h (boundary)', () {
      final result = evaluateOverexertion(
        todayIntensity: 5.0,
        avgIntensity7Day: 5.0,
        restGapHours: 4.0,
        exerciseType: 'cardio',
        thisWeekCount: 1,
        weeklyTarget: 2,
      );
      expect(result.triggered, false);
    });
  });

  group('AI Overexertion — Threshold 3: Goal Mismatch', () {
    test('Flag when this week count meets the weekly target', () {
      final result = evaluateOverexertion(
        todayIntensity: 5.0,
        avgIntensity7Day: 5.0,
        restGapHours: 24,
        exerciseType: 'strength',
        thisWeekCount: 3, // equals target
        weeklyTarget: 3,
      );
      expect(result.triggered, true);
      expect(result.reasons.any((r) => r.contains('3/week')), true);
    });

    test('No flag when this week count is below weekly target', () {
      final result = evaluateOverexertion(
        todayIntensity: 5.0,
        avgIntensity7Day: 5.0,
        restGapHours: 24,
        exerciseType: 'strength',
        thisWeekCount: 2,
        weeklyTarget: 3,
      );
      expect(result.triggered, false);
    });
  });

  group('AI Overexertion — Severity Levels', () {
    test('Severity is "caution" when only 1 threshold triggered', () {
      final result = evaluateOverexertion(
        todayIntensity: 5.0,
        avgIntensity7Day: 5.0,
        restGapHours: 5.0, // under 12h strength → 1 flag
        exerciseType: 'strength',
        thisWeekCount: 2,
        weeklyTarget: 3,
      );
      expect(result.triggered, true);
      expect(result.severity, 'caution');
    });

    test('Severity is "warning" when 2+ thresholds triggered', () {
      final result = evaluateOverexertion(
        todayIntensity: 9.0,
        avgIntensity7Day: 5.0, // delta 4.0 → flag
        restGapHours: 5.0,     // under 12h → flag
        exerciseType: 'strength',
        thisWeekCount: 2,
        weeklyTarget: 3,
      );
      expect(result.triggered, true);
      expect(result.reasons.length, greaterThanOrEqualTo(2));
      expect(result.severity, 'warning');
    });

    test('All 3 thresholds triggered — severity is "warning"', () {
      final result = evaluateOverexertion(
        todayIntensity: 9.0,
        avgIntensity7Day: 5.0, // +4.0 → flag
        restGapHours: 5.0,     // under 12h → flag
        exerciseType: 'strength',
        thisWeekCount: 3,      // equals target → flag
        weeklyTarget: 3,
      );
      expect(result.triggered, true);
      expect(result.reasons.length, 3);
      expect(result.severity, 'warning');
    });

    test('No thresholds triggered — no flag', () {
      final result = evaluateOverexertion(
        todayIntensity: 5.0,
        avgIntensity7Day: 5.0,
        restGapHours: 24,
        exerciseType: 'strength',
        thisWeekCount: 1,
        weeklyTarget: 3,
      );
      expect(result.triggered, false);
      expect(result.reasons, isEmpty);
    });
  });
}
