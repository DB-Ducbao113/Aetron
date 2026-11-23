import 'package:fitness_exercise_application/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _accountWelcomeSeenKeyPrefix = 'aetron_account_welcome_seen_v1_';

class AccountOnboardingGate extends StatefulWidget {
  const AccountOnboardingGate({
    super.key,
    required this.userId,
    required this.child,
  });

  final String userId;
  final Widget child;

  @override
  State<AccountOnboardingGate> createState() => _AccountOnboardingGateState();
}

class _AccountOnboardingGateState extends State<AccountOnboardingGate> {
  late Future<bool> _shouldShowWelcome = _loadShouldShowWelcome();

  String get _preferenceKey => '$_accountWelcomeSeenKeyPrefix${widget.userId}';

  @override
  void didUpdateWidget(covariant AccountOnboardingGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _shouldShowWelcome = _loadShouldShowWelcome();
    }
  }

  Future<bool> _loadShouldShowWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_preferenceKey) ?? false);
  }

  Future<void> _completeWelcome() async {
    if (mounted) {
      setState(() {
        _shouldShowWelcome = Future<bool>.value(false);
      });
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_preferenceKey, true);
    } catch (error) {
      debugPrint(
        '[AccountOnboardingGate] Could not persist welcome state: $error',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _shouldShowWelcome,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          final colors = context.kinetic;
          return Scaffold(
            backgroundColor: colors.background,
            body: Center(
              child: CircularProgressIndicator(color: colors.primary),
            ),
          );
        }
        return snapshot.data!
            ? WelcomeScreen(onNext: _completeWelcome)
            : widget.child;
      },
    );
  }
}
