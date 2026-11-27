import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/workout/domain/entities/workout_ai_insight.dart';
import 'package:fitness_exercise_application/features/workout/presentation/providers/workout_ai_providers.dart';
import 'package:fitness_exercise_application/features/workout/presentation/screens/details/workout_ai_insight_detail_screen.dart';
import 'package:fitness_exercise_application/features/workout/presentation/widgets/workout_ai_insight_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockEnLanguageNotifier extends AppLanguageNotifier {
  _MockEnLanguageNotifier() {
    state = AppLanguage.en;
  }
}

class _MockViLanguageNotifier extends AppLanguageNotifier {
  _MockViLanguageNotifier() {
    state = AppLanguage.vi;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({kAppLanguagePrefKey: 'vi'});
  });
  final testViInsight = WorkoutAiInsight(
    id: 'test-insight-1',
    workoutId: 'w-123',
    userId: 'u-456',
    source: 'llm',
    confidence: 0.98,
    headline: 'Buổi chạy xuất sắc với nhịp tim ổn định',
    mainInsight: 'Bạn đã duy trì tốc độ rất tốt trong suốt 5km.',
    strengths: ['Duy trì nhịp chạy đều đặn', 'Tăng tốc tốt ở chặng cuối'],
    watchouts: ['Cần chú ý bổ sung nước sau buổi chạy'],
    nextSessionSuggestion: const NextSessionSuggestion(
      recommendedActivity: 'running',
      targetDurationMin: 35,
      targetIntensity: 'aerobic',
      reason: 'Duy trì sức bền tim mạch cho tuần này.',
    ),
    usedSignals: const ['pace_fatigue_slope', 'pace_consistency_cv'],
    payloadHash: 'hash-123',
    createdAt: DateTime.now(),
  );

  final testEnInsight = WorkoutAiInsight(
    id: 'test-insight-en',
    workoutId: 'w-456',
    userId: 'u-456',
    source: 'llm',
    confidence: 0.98,
    headline: 'Running Workout Performance Recap',
    mainInsight: 'Solid running session with well-balanced pacing throughout 5km.',
    strengths: ['Maintained consistent pacing across splits'],
    watchouts: ['Remember post-workout hydration'],
    nextSessionSuggestion: const NextSessionSuggestion(
      recommendedActivity: 'running',
      targetDurationMin: 30,
      targetIntensity: 'recovery',
      reason: 'Easy recovery run to reduce muscular soreness.',
    ),
    usedSignals: const ['pace_fatigue_slope'],
    payloadHash: 'hash-en',
    createdAt: DateTime.now(),
  );

  testWidgets('WorkoutAiInsightCard renders compact preview and navigates to Detail Screen',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLanguageProvider.overrideWith((ref) => _MockViLanguageNotifier()),
          workoutAiInsightProvider('w-123')
              .overrideWith((ref) => Future.value(testViInsight)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WorkoutAiInsightCard(workoutId: 'w-123'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Phân tích từ AI Coach'), findsOneWidget);
    expect(find.text('AI Active'), findsOneWidget);
    expect(find.text('Buổi chạy xuất sắc với nhịp tim ổn định'), findsOneWidget);
    expect(find.text('Chạy bộ • 35 phút • Aerobic'), findsOneWidget);
    expect(find.text('Chi tiết'), findsOneWidget);

    // Tap on the card to navigate to full detail screen
    await tester.tap(find.byType(WorkoutAiInsightCard));
    await tester.pumpAndSettle();

    expect(find.byType(WorkoutAiInsightDetailScreen), findsOneWidget);
    expect(find.text('Phân tích từ AI Coach'), findsOneWidget);
    expect(find.text('Tổng quan hiệu suất'), findsOneWidget);
    expect(find.text('Buổi chạy xuất sắc với nhịp tim ổn định'), findsWidgets);
  });

  testWidgets('WorkoutAiInsightCard renders English compact preview and navigates to Detail Screen',
      (tester) async {
    SharedPreferences.setMockInitialValues({kAppLanguagePrefKey: 'en'});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLanguageProvider.overrideWith((ref) => _MockEnLanguageNotifier()),
          workoutAiInsightProvider('w-456')
              .overrideWith((ref) => Future.value(testEnInsight)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WorkoutAiInsightCard(workoutId: 'w-456'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('AI Coach insight'), findsOneWidget);
    expect(find.text('AI Active'), findsOneWidget);
    expect(find.text('Running Workout Performance Recap'), findsOneWidget);
    expect(find.text('Running • 30 min • Recovery'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);

    // Tap to open full page
    await tester.tap(find.byType(WorkoutAiInsightCard));
    await tester.pumpAndSettle();

    expect(find.byType(WorkoutAiInsightDetailScreen), findsOneWidget);
    expect(find.text('AI Coach analysis'), findsOneWidget);
    expect(find.text('Performance overview'), findsOneWidget);
    expect(find.text('Running Workout Performance Recap'), findsWidgets);
  });

  testWidgets('WorkoutAiInsightCard shows SMART OFFLINE badge for fallback insight',
      (tester) async {
    final fallbackInsight = WorkoutAiInsight(
      id: 'test-fallback-1',
      workoutId: 'w-123',
      userId: 'u-456',
      source: 'fallback_rule',
      confidence: 1.0,
      headline: 'Đánh giá buổi chạy bộ',
      mainInsight: 'Hoàn thành buổi tập với nhịp độ phù hợp.',
      strengths: const ['Hoàn thành bài tập đúng thời gian'],
      watchouts: const ['Bổ sung nước sau tập'],
      nextSessionSuggestion: const NextSessionSuggestion(
        recommendedActivity: 'walking',
        targetDurationMin: 25,
        targetIntensity: 'recovery',
        reason: 'Buổi tập nhẹ nhàng phục hồi cơ.',
      ),
      usedSignals: const ['pace_fatigue_slope'],
      payloadHash: 'hash-fallback',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLanguageProvider.overrideWith((ref) => _MockViLanguageNotifier()),
          workoutAiInsightProvider('w-123')
              .overrideWith((ref) => Future.value(fallbackInsight)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WorkoutAiInsightCard(workoutId: 'w-123'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Smart Offline'), findsOneWidget);
    expect(find.text('Đánh giá buổi chạy bộ'), findsOneWidget);
  });
}
