import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/models/indoor_outdoor_state.dart';
import '../providers/iod_controller.dart';

/// Interactive modal sheet to manually tag ground truth during real-world field trials.
class IodGroundTruthSheet extends ConsumerStatefulWidget {
  final bool isVi;

  const IodGroundTruthSheet({
    super.key,
    this.isVi = true,
  });

  @override
  ConsumerState<IodGroundTruthSheet> createState() =>
      _IodGroundTruthSheetState();
}

class _IodGroundTruthSheetState extends ConsumerState<IodGroundTruthSheet> {
  final TextEditingController _noteController = TextEditingController();
  bool _isExporting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iodState = ref.watch(iodControllerProvider);
    final prediction = iodState.currentPrediction;
    final activeGt = iodState.activeGroundTruth;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 16,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF14161D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.isVi
                      ? 'Đánh dấu Môi trường (Ground Truth)'
                      : 'Mark Ground Truth Environment',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Diagnostic Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E212A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: prediction.state.color.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'AI: ${prediction.state.localizedLabel(widget.isVi)} (${(prediction.confidence * 100).toStringAsFixed(0)}%)',
                      style: TextStyle(
                        color: prediction.state.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${prediction.inferenceLatencyMs}ms | ${iodState.totalSamplesCount} samples',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  prediction.reasoningSummary,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quick Label Chips
          Text(
            widget.isVi
                ? 'CHỌN NHÃN MÔI TRƯỜNG THỰC TẾ:'
                : 'SELECT REFERENCE GROUND TRUTH:',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildGroundTruthChip(
                env: GroundTruthEnvironment.indoor,
                icon: Icons.roofing_rounded,
                color: const Color(0xFF3B82F6),
                activeGt: activeGt,
              ),
              _buildGroundTruthChip(
                env: GroundTruthEnvironment.outdoor,
                icon: Icons.wb_sunny_rounded,
                color: const Color(0xFF10B981),
                activeGt: activeGt,
              ),
              _buildGroundTruthChip(
                env: GroundTruthEnvironment.transition,
                icon: Icons.door_sliding_rounded,
                color: const Color(0xFFF59E0B),
                activeGt: activeGt,
              ),
              _buildGroundTruthChip(
                env: GroundTruthEnvironment.urbanCanyon,
                icon: Icons.location_city_rounded,
                color: const Color(0xFF8B5CF6),
                activeGt: activeGt,
              ),
              _buildGroundTruthChip(
                env: GroundTruthEnvironment.nearWindow,
                icon: Icons.window_rounded,
                color: const Color(0xFF06B6D4),
                activeGt: activeGt,
              ),
              _buildGroundTruthChip(
                env: GroundTruthEnvironment.coveredOutdoor,
                icon: Icons.deck_rounded,
                color: const Color(0xFF14B8A6),
                activeGt: activeGt,
              ),
              _buildGroundTruthChip(
                env: GroundTruthEnvironment.stationary,
                icon: Icons.pause_circle_outline_rounded,
                color: const Color(0xFFEC4899),
                activeGt: activeGt,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Note Field
          TextField(
            controller: _noteController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: widget.isVi
                  ? 'Ghi chú bổ sung (VD: Qua cửa kính, xuống hầm)'
                  : 'Add context note (e.g. glass door, basement)',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF1E212A),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons: Export & Close
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isExporting ? null : _exportData,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.share_rounded, size: 16),
                  label: Text(
                    widget.isVi ? 'Xuất CSV / JSON' : 'Export Data',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    widget.isVi ? 'Hoàn tất' : 'Done',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroundTruthChip({
    required GroundTruthEnvironment env,
    required IconData icon,
    required Color color,
    required GroundTruthEnvironment? activeGt,
  }) {
    final isSelected = activeGt == env;

    return InkWell(
      onTap: () {
        ref.read(iodControllerProvider.notifier).markGroundTruth(
              env,
              note: _noteController.text.trim().isNotEmpty
                  ? _noteController.text.trim()
                  : null,
            );
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.3)
              : const Color(0xFF1E212A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? color : Colors.white60,
            ),
            const SizedBox(width: 6),
            Text(
              env.localizedLabel(widget.isVi),
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportData() async {
    setState(() => _isExporting = true);
    try {
      final csvPath =
          await ref.read(iodControllerProvider.notifier).exportCsv();
      final jsonPath =
          await ref.read(iodControllerProvider.notifier).exportJson();

      final files = <XFile>[];
      if (csvPath != null) files.add(XFile(csvPath));
      if (jsonPath != null) files.add(XFile(jsonPath));

      if (files.isNotEmpty) {
        await Share.shareXFiles(
          files,
          text: 'Aetron IOD Benchmark Dataset (${files.length} files)',
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.isVi
                    ? 'Chưa có dữ liệu phiên để xuất.'
                    : 'No session data to export yet.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}
