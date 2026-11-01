// lib/pages/journal_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../models/journal_entry.dart';
import '../widgets/custom_app_bar.dart';
import '../theme/app_theme.dart';
import '../dialogs/journal_dialog.dart';
import 'journal_detail_page.dart';

class JournalPage extends StatelessWidget {
  static const routeName = '/journal';
  const JournalPage({Key? key}) : super(key: key);

  String _safeTitle(JournalEntry e) {
    final t = e.title.trim();
    return t.isEmpty ? 'Без названия' : t;
  }

  String _safePreview(JournalEntry e) {
    final c = e.content.trim();
    if (c.isEmpty) return '— нет содержимого —';
    return c.length > 80 ? '${c.substring(0, 80)}…' : c;
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final entries = st.journalEntries;

    return Scaffold(
      appBar: const CustomAppBar(
        title: Text('Дневник', style: TextStyle(color: Colors.white)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showJournalDialog(context),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Запись', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: entries.isEmpty
            ? _EmptyJournal(onAdd: () => showJournalDialog(context))
            : ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final e = entries[i];
                  final hasImages = e.imagePaths.isNotEmpty;

                  return Dismissible(
                    key: ValueKey(e.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(AppRadii.xl),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_rounded, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Удалить',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    onDismissed: (_) {
                      context.read<AppState>().deleteJournalEntry(e);
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(const SnackBar(content: Text('Запись удалена')));
                    },
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => JournalDetailPage(entry: e)),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadii.xl),
                          border: Border.all(color: AppColors.border),
                          boxShadow: AppShadows.card,
                        ),
                        padding: const EdgeInsets.all(14),
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
                                  color: AppColors.accent.withAlpha((0.18 * 255).round()),
                                ),
                              ),
                              child: Icon(
                                hasImages ? Icons.collections_rounded : Icons.book_rounded,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _safeTitle(e),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w900,
                                                color: AppColors.textPrimary,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      if (hasImages)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withAlpha((0.10 * 255).round()),
                                            borderRadius: BorderRadius.circular(999),
                                            border: Border.all(
                                              color: const Color(0xFF10B981).withAlpha((0.18 * 255).round()),
                                            ),
                                          ),
                                          child: Text(
                                            '${e.imagePaths.length} фото',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 12,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _safePreview(e),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: const [
                                      Icon(Icons.swipe_left_rounded, size: 16, color: AppColors.textMuted),
                                      SizedBox(width: 6),
                                      Text(
                                        'Свайп влево — удалить',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Spacer(),
                                      Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _EmptyJournal extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyJournal({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.accent.withAlpha((0.12 * 255).round()),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.accent.withAlpha((0.18 * 255).round())),
              ),
              child: const Icon(Icons.book_rounded, color: AppColors.accent),
            ),
            const SizedBox(height: 14),
            Text(
              'Записей пока нет',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Создай первую запись — за дневник ты получаешь XP.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Добавить запись'),
            ),
          ],
        ),
      ),
    );
  }
}
