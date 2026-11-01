// lib/pages/store_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/custom_app_bar.dart';
import '../theme/app_theme.dart';

class StorePage extends StatelessWidget {
  static const routeName = '/store';

  const StorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();

    return Scaffold(
      appBar: const CustomAppBar(
        title: Text('Магазин', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // карточка обмена
            Container(
              decoration: AppDecorations.card(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.pageBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.swap_horiz_rounded, color: AppColors.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Обмен XP → монеты',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '10 XP = 1 монета • Баланс: ${st.xpBalance} XP',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120, // важно: фиксируем ширину
                      height: 40,
                      child: FilledButton(
                        onPressed: () {
                          final ok = st.exchangeXpForCoins(1);
                          if (!ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Недостаточно XP')),
                            );
                          }
                        },
                        child: const Text('Обменять'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            _StoreItem(
              id: 'theme_dark',
              name: 'Тёмная тема',
              price: 5,
              icon: Icons.dark_mode_rounded,
            ),
            const SizedBox(height: 12),
            _StoreItem(
              id: 'avatar_cat',
              name: 'Аватар «Котик»',
              price: 10,
              icon: Icons.pets_rounded,
            ),
            const SizedBox(height: 12),
            _StoreItem(
              id: 'extra_life',
              name: 'Доп. жизнь для привычек',
              price: 3,
              icon: Icons.favorite_rounded,
            ),
            const SizedBox(height: 12),
            _StoreItem(
              id: 'xp_booster',
              name: 'XP-бустер +50',
              price: 3,
              icon: Icons.bolt_rounded,
            ),
            const SizedBox(height: 12),
            _StoreItem(
              id: 'calendar_skin',
              name: 'Новая тема календаря',
              price: 8,
              icon: Icons.palette_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreItem extends StatelessWidget {
  final String id;
  final String name;
  final int price;
  final IconData icon;

  const _StoreItem({
    required this.id,
    required this.name,
    required this.price,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final purchased = st.isPurchased(id);

    return Container(
      decoration: AppDecorations.card(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.pageBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(icon, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    '$price монет • Баланс: ${st.coins}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 110, // важно: фиксируем ширину
              height: 40,
              child: FilledButton(
                onPressed: purchased
                    ? null
                    : () {
                        final ok = st.purchaseItem(id, price);
                        if (!ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Недостаточно монет')),
                          );
                          return;
                        }

                        if (id == 'xp_booster') {
                          st.addXp(50);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('+50 XP получено!')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Покупка успешна!')),
                          );
                        }
                      },
                child: Text(purchased ? 'Куплено' : 'Купить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
