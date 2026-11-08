// lib/pages/journal_detail_page.dart

import 'dart:io';
import 'package:flutter/material.dart';

import '../models/journal_entry.dart';
import '../widgets/custom_app_bar.dart';
import '../dialogs/journal_dialog.dart';
import '../theme/app_theme.dart';

class JournalDetailPage extends StatelessWidget {
  final JournalEntry entry;
  const JournalDetailPage({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final title = entry.title.trim().isEmpty
        ? 'Без названия'
        : entry.title.trim();
    final content = entry.content.trim().isEmpty
        ? '— нет содержимого —'
        : entry.content.trim();

    return Scaffold(
      appBar: const CustomAppBar(
        title: Text('Просмотр записи', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header card
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.card,
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withAlpha((0.12 * 255).round()),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.accent.withAlpha(
                            (0.18 * 255).round(),
                          ),
                        ),
                      ),
                      child: const Icon(
                        Icons.book_rounded,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              height: 1.15,
                            ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Content card
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadii.xl),
                          border: Border.all(color: AppColors.border),
                          boxShadow: AppShadows.card,
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          content,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: AppColors.textPrimary,
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),

                      if (entry.imagePaths.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadii.xl),
                            border: Border.all(color: AppColors.border),
                            boxShadow: AppShadows.card,
                          ),
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Вложения',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textPrimary,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 112,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: entry.imagePaths.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 10),
                                  itemBuilder: (ctx, i) {
                                    final path = entry.imagePaths[i];
                                    return _ImageThumb(path: path);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Bottom actions
              ElevatedButton.icon(
                onPressed: () => showJournalDialog(context, entry: entry),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Редактировать'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Назад'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  final String path;
  const _ImageThumb({required this.path});

  @override
  Widget build(BuildContext context) {
    final file = File(path);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.l),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => Dialog(
              insetPadding: const EdgeInsets.all(16),
              backgroundColor: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.xl),
                child: Container(
                  color: Colors.black,
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Image.file(file, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          );
        },
        child: Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            color: AppColors.pageBg,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadii.l),
          ),
          child: Image.file(file, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
