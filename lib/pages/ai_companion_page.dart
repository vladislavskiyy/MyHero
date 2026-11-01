// lib/pages/ai_companion_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_app_bar.dart';

class AiCompanionPage extends StatefulWidget {
  static const routeName = '/companion';
  const AiCompanionPage({super.key});

  @override
  State<AiCompanionPage> createState() => _AiCompanionPageState();
}

enum _Sender { user, ai }

class _ChatMessage {
  final _Sender sender;
  final String text;
  final DateTime ts;

  _ChatMessage({
    required this.sender,
    required this.text,
    DateTime? ts,
  }) : ts = ts ?? DateTime.now();
}

class _AiCompanionPageState extends State<AiCompanionPage> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  final List<_ChatMessage> _messages = [
    _ChatMessage(
      sender: _Sender.ai,
      text:
          'Привет! Я твой AI-компаньон 🙂\nМогу помочь: распланировать день, разбить задачу, подобрать привычки и подвести итоги.',
    ),
  ];

  bool _isTyping = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(sender: _Sender.user, text: text));
      _isTyping = true;
    });
    _ctrl.clear();
    _scrollToBottomSoon();

    // имитация "печатает"
    await Future<void>.delayed(const Duration(milliseconds: 450));

    final reply = _generateReply(text);
    if (!mounted) return;

    setState(() {
      _messages.add(_ChatMessage(sender: _Sender.ai, text: reply));
      _isTyping = false;
    });
    _scrollToBottomSoon();
  }

  void _scrollToBottomSoon() {
    // reverse: true => "низ" это offset=0
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  String _generateReply(String input) {
    final s = input.toLowerCase();

    if (s.contains('план') || s.contains('день')) {
      return 'Ок, сделаем план на день.\n\n1) Назови 3 главные задачи.\n2) Сколько времени у тебя сегодня (в минутах)?\n3) Есть ли жёсткие дедлайны/встречи?';
    }
    if (s.contains('разбей') || s.contains('декомпоз') || s.contains('задач')) {
      return 'Давай декомпозируем.\n\nНапиши:\n• цель задачи\n• дедлайн\n• что уже готово\nИ я разложу на шаги + дам оценку времени.';
    }
    if (s.contains('мотивац') || s.contains('лень') || s.contains('не хочу')) {
      return 'Понял. Давай мягко вернём мотивацию.\n\nВыбери вариант:\nA) 5 минут “разогрев”\nB) 1 маленький шаг прямо сейчас\nC) убрать препятствие (что мешает?)';
    }
    if (s.contains('итоги') || s.contains('рефлекс') || s.contains('дневник')) {
      return 'Давай подведём итоги дня.\n\nОтветь коротко:\n1) Что получилось?\n2) Что мешало?\n3) 1 улучшение на завтра?';
    }

    return 'Ок 🙂\nСкажи, что именно хочешь получить: план, декомпозицию, мотивацию или итоги?';
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();

    return Scaffold(
      appBar: const CustomAppBar(
        title: Text('AI-компаньон', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final maxW = c.maxWidth > 720 ? 720.0 : c.maxWidth;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                      child: _CompanionHeader(
                        level: st.level,
                        xp: st.xpBalance,
                        coins: st.coins,
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _QuickActions(
                        onTap: (t) => _send(t),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Expanded(
                      child: Stack(
                        children: [
                          // ЧАТ
                          ListView.builder(
                            controller: _scroll,
                            reverse: true,
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                            itemCount: _messages.length + (_isTyping ? 1 : 0),
                            itemBuilder: (ctx, idx) {
                              if (_isTyping && idx == 0) {
                                return const _TypingBubble();
                              }
                              final mIndex = _isTyping ? idx - 1 : idx;
                              final m = _messages.reversed.toList()[mIndex];
                              return _ChatBubble(message: m);
                            },
                          ),
                        ],
                      ),
                    ),

                    // ВВОД
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: _Composer(
                        controller: _ctrl,
                        onSend: _send,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CompanionHeader extends StatelessWidget {
  final int level;
  final int xp;
  final int coins;

  const _CompanionHeader({
    required this.level,
    required this.xp,
    required this.coins,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card(radius: AppRadii.xl),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.accent, Color(0xFF14B8A6)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: AppShadows.card,
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Nomi',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                SizedBox(height: 3),
                Text(
                  'План • Мотивация • Итоги',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          _MiniPill(label: 'LVL', value: '$level'),
          const SizedBox(width: 8),
          _MiniPill(label: 'XP', value: '$xp'),
          const SizedBox(width: 8),
          _MiniPill(label: '🪙', value: '$coins'),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;
  final String value;

  const _MiniPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
          const SizedBox(width: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final void Function(String) onTap;
  const _QuickActions({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = <String>[
      'Составь план на день',
      'Разбей задачу на шаги',
      'Нужна мотивация',
      'Подвести итоги дня',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((t) {
        return InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => onTap(t),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              t,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontSize: 12.5,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == _Sender.user;

    final bg = isUser ? AppColors.accent : AppColors.surface;
    final fg = isUser ? Colors.white : AppColors.textPrimary;
    final border = isUser ? Colors.transparent : AppColors.border;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppRadii.xl),
                  topRight: Radius.circular(AppRadii.xl),
                  bottomLeft: Radius.circular(isUser ? AppRadii.xl : 8),
                  bottomRight: Radius.circular(isUser ? 8 : AppRadii.xl),
                ),
                border: Border.all(color: border),
                boxShadow: isUser ? AppShadows.card : null,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(
                message.text,
                style: TextStyle(
                  color: fg,
                  fontSize: 14.5,
                  height: 1.25,
                  fontWeight: isUser ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> {
  int _dots = 1;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 280), (_) {
      if (!mounted) return;
      setState(() => _dots = _dots == 3 ? 1 : _dots + 1);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = '.' * _dots;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.xl),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text(
              'Печатает$text',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final Future<void> Function(String) onSend;

  const _Composer({
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onSubmitted: (v) => onSend(v),
              decoration: const InputDecoration(
                hintText: 'Напиши сообщение…',
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            height: 44,
            child: FilledButton(
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => onSend(controller.text),
              child: const Icon(Icons.send_rounded, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
