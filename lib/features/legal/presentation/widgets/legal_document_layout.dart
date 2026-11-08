import 'package:fitness_exercise_application/core/legal/legal_documents.dart';
import 'package:fitness_exercise_application/core/localization/app_translations.dart';
import 'package:fitness_exercise_application/features/legal/presentation/widgets/legal_info_panel.dart';
import 'package:fitness_exercise_application/shared/kinetic/kinetic.dart';
import 'package:flutter/material.dart';

/// Clean, document-oriented layout component for long-form legal reading.
/// Designed for high readability, calm aesthetics, and natural scrolling.
class LegalDocumentLayout extends StatelessWidget {
  const LegalDocumentLayout({
    super.key,
    required this.title,
    required this.lastUpdated,
    required this.sections,
    required this.lang,
    this.showDisclaimer = true,
  });

  final String title;
  final String lastUpdated;
  final List<LegalDocumentSection> sections;
  final AppLanguage lang;
  final bool showDisclaimer;

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Standard Document Header with Back Button
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: KineticTokens.spaceMD,
                vertical: KineticTokens.spaceSM,
              ),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.borderSubtle)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang == AppLanguage.vi
                              ? 'VĂN BẢN PHÁP LÝ'
                              : 'LEGAL DOCUMENT',
                          style: KineticTypography.pageEyebrow.copyWith(
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title.toUpperCase(),
                          style: KineticTypography.headlineSmall.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Main Document Scroll View
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                horizontal: KineticTokens.page,
                vertical: KineticTokens.spaceMD,
              ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Document Metadata Banner
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.secondary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colors.secondary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            lang == AppLanguage.vi
                                ? 'VĂN BẢN CHÍNH THỨC'
                                : 'OFFICIAL DOCUMENT',
                            style: KineticTypography.unitLabel.copyWith(
                              color: colors.secondary,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${lang == AppLanguage.vi ? 'Cập nhật lần cuối' : 'Last updated'}: $lastUpdated',
                          style: KineticTypography.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: KineticTokens.spaceMD),

                    // Restrained Fitness & Health Disclaimer Info Panel
                    if (showDisclaimer) ...[
                      LegalInfoPanel(lang: lang),
                      const SizedBox(height: KineticTokens.spaceLG),
                    ],

                    // Compact "ON THIS PAGE" Table of Contents List
                    _TableOfContents(sections: sections, lang: lang),
                    const SizedBox(height: KineticTokens.spaceXL),

                    Divider(
                      color: colors.borderSubtle,
                      height: 1,
                    ),
                    const SizedBox(height: KineticTokens.spaceXL),

                    // Document Sections List (High-readability typography)
                    for (var i = 0; i < sections.length; i++) ...[
                      _LegalSectionBlock(
                        index: i + 1,
                        section: sections[i],
                      ),
                      if (i != sections.length - 1)
                        const SizedBox(height: KineticTokens.spaceXL),
                    ],

                    const SizedBox(height: KineticTokens.spaceXXL),
                    Center(
                      child: Text(
                        '— ${lang == AppLanguage.vi ? 'Hết tài liệu' : 'End of Document'} —',
                        style: KineticTypography.bodySmall.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: KineticTokens.spaceXXXL),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableOfContents extends StatelessWidget {
  const _TableOfContents({
    required this.sections,
    required this.lang,
  });

  final List<LegalDocumentSection> sections;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return Container(
      padding: const EdgeInsets.all(KineticTokens.spaceMD),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(KineticTokens.radiusLG),
        border: Border.all(color: colors.borderStrong, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.list_alt_rounded,
                color: colors.textSecondary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                lang == AppLanguage.vi ? 'MỤC LỤC TRANG' : 'ON THIS PAGE',
                style: KineticTypography.unitLabel.copyWith(
                  color: colors.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: colors.borderSubtle, height: 1),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: sections.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(
                      (entry.key + 1).toString().padLeft(2, '0'),
                      style: KineticTypography.label.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.value.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KineticTypography.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.textMuted,
                      size: 18,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _LegalSectionBlock extends StatelessWidget {
  const _LegalSectionBlock({
    required this.index,
    required this.section,
  });

  final int index;
  final LegalDocumentSection section;

  @override
  Widget build(BuildContext context) {
    final colors = context.kinetic;

    return KineticCard(
      padding: const EdgeInsets.all(KineticTokens.spaceMD),
      borderRadius: KineticTokens.radiusLG,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title — numbered heading (primary numeral + title)
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                index.toString().padLeft(2, '0'),
                style: KineticTypography.headlineSmall.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.title,
                  style: KineticTypography.headlineSmall.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Section Body Content
          SelectableText(
            section.content,
            style: KineticTypography.bodyMedium.copyWith(
              color: colors.textPrimary.withValues(alpha: 0.9),
              height: 1.65,
              letterSpacing: 0.15,
            ),
          ),
        ],
      ),
    );
  }
}
