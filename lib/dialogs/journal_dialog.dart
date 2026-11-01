// lib/dialogs/journal_dialog.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../state/app_state.dart';
import '../models/journal_entry.dart';
import '../theme/app_theme.dart';

Future<void> showJournalDialog(
  BuildContext context, {
  JournalEntry? entry,
}) async {
  final isEdit = entry != null;

  final titleCtrl = TextEditingController(text: entry?.title ?? '');
  final contentCtrl = TextEditingController(text: entry?.content ?? '');

  final images = List<String>.from(entry?.imagePaths ?? <String>[]);
  final picker = ImagePicker();

  Future<void> pickImage() async {
    final XFile? file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final savedFile = await File(file.path).copy('${appDir.path}/$fileName');
    images.add(savedFile.path);
  }

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (ctx, setState) {
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 24,
                      offset: Offset(0, -8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isEdit ? 'Редактирование записи' : 'Новая запись',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Закрыть',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: titleCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'Заголовок',
                        prefixIcon: Icon(Icons.title_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: contentCtrl,
                      minLines: 5,
                      maxLines: 10,
                      decoration: const InputDecoration(
                        hintText: 'Содержание',
                        prefixIcon: Icon(Icons.notes_rounded),
                        alignLabelWithHint: true,
                      ),
                    ),

                    const SizedBox(height: 14),

                    Row(
                      children: [
                        const Icon(Icons.photo_library_rounded,
                            color: AppColors.textMuted),
                        const SizedBox(width: 8),
                        Text(
                          'Фото',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const Spacer(),
                        Text(
                          '${images.length}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    SizedBox(
                      height: 86,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final path in images)
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(AppRadii.m),
                                    child: Image.file(
                                      File(path),
                                      width: 86,
                                      height: 86,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: InkWell(
                                      onTap: () => setState(() => images.remove(path)),
                                      borderRadius: BorderRadius.circular(999),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.55),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          InkWell(
                            onTap: () async {
                              await pickImage();
                              setState(() {});
                            },
                            borderRadius: BorderRadius.circular(AppRadii.m),
                            child: Container(
                              width: 86,
                              height: 86,
                              decoration: BoxDecoration(
                                color: AppColors.pageBg,
                                borderRadius: BorderRadius.circular(AppRadii.m),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_rounded,
                                      size: 30, color: AppColors.textMuted),
                                  SizedBox(height: 4),
                                  Text(
                                    'Добавить',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      onPressed: () {
                        final title = titleCtrl.text.trim();
                        final content = contentCtrl.text.trim();

                        if (title.isEmpty || content.isEmpty) {
                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text('Введите и заголовок, и содержание'),
                              ),
                            );
                          return;
                        }

                        final appState = context.read<AppState>();

                        if (!isEdit) {
                          final newEntry = JournalEntry(
                            id: DateTime.now().toIso8601String(),
                            title: title,
                            content: content,
                            date: DateTime.now(),
                            imagePaths: List<String>.from(images),
                          );

                          appState.addJournalEntry(newEntry);

                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(
                              const SnackBar(content: Text('+3 XP за новую запись!')),
                            );
                        } else {
                          // ВАЖНО: не используем clear/addAll — просто присваиваем новый список
                          entry.title = title;
                          entry.content = content;
                          entry.imagePaths = List<String>.from(images);

                          appState.updateJournalEntry(
                            entry,
                            title: title,
                            content: content,
                          );
                        }

                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: Text(isEdit ? 'Сохранить' : 'Создать'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  );
}
