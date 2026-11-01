import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../theme/app_theme.dart';
import '../main.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  static const routeName = '/onboarding';

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  final List<_OnboardingData> _slides = const [
    _OnboardingData(
      icon: Icons.today_rounded,
      title: 'Сначала — день',
      subtitle: 'Планируй сегодня, а не всё сразу. Ваша главная задача всегда рядом.',
      accent: Color(0xFF4F46E5),
    ),
    _OnboardingData(
      icon: Icons.checklist_rounded,
      title: 'Дела по важности',
      subtitle: 'Следите за приоритетами, дедлайнами и задачами, которые реально двигают день вперёд.',
      accent: Color(0xFF0EA5A4),
    ),
    _OnboardingData(
      icon: Icons.auto_awesome_rounded,
      title: 'Привычки и прогресс',
      subtitle: 'Отмечайте привычки, развивайте streak и получайте XP за регулярность.',
      accent: Color(0xFFF59E0B),
    ),
    _OnboardingData(
      icon: Icons.rocket_launch_rounded,
      title: 'Готово к старту',
      subtitle: 'Приложение поможет держать фокус, не перегружаться и двигаться без хаоса.',
      accent: Color(0xFF10B981),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    final box = Hive.box('settings');
    await box.put('seenOnboarding', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentIndex == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _finishOnboarding,
                  child: const Text('Пропустить'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (index) => setState(() => _currentIndex = index),
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [slide.accent, slide.accent.withAlpha((0.72 * 255).round())],
                              ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: AppShadows.card,
                            ),
                            child: Icon(slide.icon, size: 52, color: Colors.white),
                          ),
                          const SizedBox(height: 26),
                          Text(
                            slide.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Text(
                              slide.subtitle,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppColors.textMuted,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: _currentIndex == index ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: _currentIndex == index ? AppColors.accent : AppColors.border,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (isLast) {
                      _finishOnboarding();
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                  child: Text(isLast ? 'Начать' : 'Далее'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  const _OnboardingData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });
}
