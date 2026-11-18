import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows a sleek, Cyber-Kinetic numeric time input bottom sheet
/// Replacing the complex analog dial clock with simple numeric inputs and quick presets.
Future<String?> showKineticTimeInputSheet(
  BuildContext context, {
  required String initialTime,
  required bool isVi,
}) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => KineticTimeInputSheet(
      initialTime: initialTime,
      isVi: isVi,
    ),
  );
}

class KineticTimeInputSheet extends StatefulWidget {
  final String initialTime;
  final bool isVi;

  const KineticTimeInputSheet({
    super.key,
    required this.initialTime,
    required this.isVi,
  });

  @override
  State<KineticTimeInputSheet> createState() => _KineticTimeInputSheetState();
}

class _KineticTimeInputSheetState extends State<KineticTimeInputSheet> {
  late TextEditingController _hourController;
  late TextEditingController _minuteController;
  late FocusNode _hourFocus;
  late FocusNode _minuteFocus;

  final List<String> _quickPresets = const [
    '06:00',
    '07:00',
    '08:00',
    '17:30',
    '18:00',
    '20:00',
    '22:00',
  ];

  @override
  void initState() {
    super.initState();
    final parts = widget.initialTime.split(':');
    final initialHour = (parts.isNotEmpty ? int.tryParse(parts[0]) : 8) ?? 8;
    final initialMinute = (parts.length > 1 ? int.tryParse(parts[1]) : 0) ?? 0;

    _hourController = TextEditingController(
      text: initialHour.toString().padLeft(2, '0'),
    );
    _minuteController = TextEditingController(
      text: initialMinute.toString().padLeft(2, '0'),
    );

    _hourFocus = FocusNode();
    _minuteFocus = FocusNode();

    // Select text on focus for quick typing
    _hourFocus.addListener(() {
      if (_hourFocus.hasFocus) {
        _hourController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _hourController.text.length,
        );
      }
      setState(() {});
    });

    _minuteFocus.addListener(() {
      if (_minuteFocus.hasFocus) {
        _minuteController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _minuteController.text.length,
        );
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _hourFocus.dispose();
    _minuteFocus.dispose();
    super.dispose();
  }

  void _adjustHour(int delta) {
    HapticFeedback.lightImpact();
    final current = int.tryParse(_hourController.text) ?? 8;
    final updated = (current + delta + 24) % 24;
    _hourController.text = updated.toString().padLeft(2, '0');
    setState(() {});
  }

  void _adjustMinute(int delta) {
    HapticFeedback.lightImpact();
    final current = int.tryParse(_minuteController.text) ?? 0;
    final updated = (current + delta + 60) % 60;
    _minuteController.text = updated.toString().padLeft(2, '0');
    setState(() {});
  }

  void _applyPreset(String preset) {
    HapticFeedback.selectionClick();
    final parts = preset.split(':');
    if (parts.length == 2) {
      _hourController.text = parts[0];
      _minuteController.text = parts[1];
      setState(() {});
    }
  }

  void _confirm() {
    HapticFeedback.mediumImpact();
    final rawHour = int.tryParse(_hourController.text) ?? 8;
    final rawMinute = int.tryParse(_minuteController.text) ?? 0;

    final hour = rawHour.clamp(0, 23);
    final minute = rawMinute.clamp(0, 59);

    final formatted =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    Navigator.of(context).pop(formatted);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isVi = widget.isVi;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      padding: EdgeInsets.fromLTRB(
        KineticTokens.spaceLG,
        KineticTokens.spaceMD,
        KineticTokens.spaceLG,
        KineticTokens.spaceXL + bottomInset,
      ),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(KineticTokens.radiusXXL),
        border: Border.all(
          color: colors.borderStrong,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 36,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Grab Handle
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderSubtle,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row with Clock Icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(
                    Icons.access_time_filled_rounded,
                    color: colors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVi ? 'CÀI ĐẶT THỜI GIAN' : 'SET TIME',
                        style: KineticTypography.headlineSmall.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isVi
                            ? 'Nhập số giờ (00-23) và phút (00-59)'
                            : 'Enter hour (00-23) and minute (00-59)',
                        style: KineticTypography.bodySmall.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Direct Number Inputs with Steppers
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // HOUR INPUT BOX
                _NumericTimeBox(
                  controller: _hourController,
                  focusNode: _hourFocus,
                  label: isVi ? 'GIỜ' : 'HOUR',
                  colors: colors,
                  onIncrement: () => _adjustHour(1),
                  onDecrement: () => _adjustHour(-1),
                  onChanged: (val) {
                    if (val.length == 2) {
                      _minuteFocus.requestFocus();
                    }
                  },
                ),
                const SizedBox(width: 14),

                // TIME SEPARATOR COLON
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    ':',
                    style: KineticTypography.metricHero.copyWith(
                      fontSize: 38,
                      color: colors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // MINUTE INPUT BOX
                _NumericTimeBox(
                  controller: _minuteController,
                  focusNode: _minuteFocus,
                  label: isVi ? 'PHÚT' : 'MINUTE',
                  colors: colors,
                  onIncrement: () => _adjustMinute(5),
                  onDecrement: () => _adjustMinute(-5),
                  onChanged: (val) {
                    if (val.length >= 2) {
                      _minuteFocus.unfocus();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Quick Preset Chips
            Text(
              isVi ? 'GỢI Ý NHANH:' : 'QUICK PRESETS:',
              style: KineticTypography.sectionEyebrow.copyWith(
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final preset in _quickPresets) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(preset),
                        labelStyle: KineticTypography.label.copyWith(
                          color: (_hourController.text == preset.split(':')[0] &&
                                  _minuteController.text == preset.split(':')[1])
                              ? colors.onPrimary
                              : colors.textSecondary,
                        ),
                        backgroundColor:
                            (_hourController.text == preset.split(':')[0] &&
                                    _minuteController.text == preset.split(':')[1])
                                ? colors.primary
                                : colors.surface2,
                        side: BorderSide(
                          color: (_hourController.text == preset.split(':')[0] &&
                                  _minuteController.text == preset.split(':')[1])
                              ? colors.primary
                              : colors.borderSubtle,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        onPressed: () => _applyPreset(preset),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textSecondary,
                        side: BorderSide(color: colors.borderSubtle),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            KineticTokens.radiusMD,
                          ),
                        ),
                      ),
                      child: Text(
                        isVi ? 'HỦY' : 'CANCEL',
                        style: KineticTypography.label.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        elevation: 4,
                        shadowColor: colors.primary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            KineticTokens.radiusMD,
                          ),
                        ),
                      ),
                      child: Text(
                        isVi ? 'XÁC NHẬN' : 'CONFIRM',
                        style: KineticTypography.label.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NumericTimeBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final KineticColors colors;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final ValueChanged<String> onChanged;

  const _NumericTimeBox({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.colors,
    required this.onIncrement,
    required this.onDecrement,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isFocused = focusNode.hasFocus;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Up stepper arrow
        IconButton(
          onPressed: onIncrement,
          icon: Icon(
            Icons.keyboard_arrow_up_rounded,
            size: 26,
            color: colors.textMuted,
          ),
          splashRadius: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 30),
        ),
        // Main input container
        Container(
          width: 86,
          height: 68,
          decoration: BoxDecoration(
            color: colors.surface2,
            borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
            border: Border.all(
              color: isFocused ? colors.primary : colors.borderSubtle,
              width: isFocused ? 2 : 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            style: KineticTypography.metricHero.copyWith(
              fontSize: 32,
              color: colors.textPrimary,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
            onChanged: onChanged,
          ),
        ),
        // Down stepper arrow
        IconButton(
          onPressed: onDecrement,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 26,
            color: colors.textMuted,
          ),
          splashRadius: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 30),
        ),
        Text(
          label,
          style: KineticTypography.unitLabel.copyWith(
            color: isFocused ? colors.primary : colors.textMuted,
          ),
        ),
      ],
    );
  }
}
