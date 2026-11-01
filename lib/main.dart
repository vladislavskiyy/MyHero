import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'services/notification_service.dart';
import 'services/auth_service.dart';
import 'state/app_state.dart';

import 'pages/lists_overview_page.dart' show ToolsOverviewPage;
import 'pages/calendar_page.dart';
import 'pages/profile_page.dart';
import 'pages/achievements_page.dart';
import 'pages/store_page.dart';
import 'pages/habit_tracker_page.dart';
import 'pages/settings_page.dart';
import 'pages/journal_page.dart';
import 'pages/scheduler_page.dart';
import 'pages/login_page.dart';
import 'pages/signup_page.dart';
import 'pages/today_page.dart';
import 'pages/onboarding_page.dart';

// ✅ ДОБАВЬ
import 'pages/ai_companion_page.dart';

import 'models/task.dart';
import 'models/habit.dart';
import 'models/task_list.dart';
import 'models/journal_entry.dart';
import 'models/achievement.dart';
import 'theme/app_theme.dart';
import 'pages/inbox_page.dart';

final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

Future<Uint8List> _loadOrCreateHiveKey() async {
  const keyName = 'hive_encryption_key';
  String? encodedKey = await _secureStorage.read(
    key: keyName,
    aOptions: const AndroidOptions(encryptedSharedPreferences: true),
  );
  if (encodedKey != null) {
    return base64Url.decode(encodedKey);
  }
  final rnd = Random.secure();
  final keyBytes = List<int>.generate(32, (_) => rnd.nextInt(256));
  final newKey = Uint8List.fromList(keyBytes);
  await _secureStorage.write(
    key: keyName,
    value: base64Url.encode(newKey),
    aOptions: const AndroidOptions(encryptedSharedPreferences: true),
  );
  return newKey;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  await AuthService.init();
  final current = AuthService.currentUser();

  Hive.registerAdapter(TaskAdapter());
  Hive.registerAdapter(HabitAdapter());
  Hive.registerAdapter(TaskListAdapter());
  Hive.registerAdapter(JournalEntryAdapter());
  Hive.registerAdapter(AchievementAdapter());
  Hive.registerAdapter(AchievementTypeAdapter());

  final hiveKey = await _loadOrCreateHiveKey();
  final hiveCipher = HiveAesCipher(hiveKey);

  await Hive.openBox<String>('auth', encryptionCipher: hiveCipher);
  await Hive.openBox<Task>('tasks', encryptionCipher: hiveCipher);
  await Hive.openBox<Habit>('habits', encryptionCipher: hiveCipher);
  await Hive.openBox<TaskList>('task_lists', encryptionCipher: hiveCipher);
  await Hive.openBox<JournalEntry>('journal_entries', encryptionCipher: hiveCipher);
  await Hive.openBox<Achievement>('achievements', encryptionCipher: hiveCipher);
  await Hive.openBox('settings', encryptionCipher: hiveCipher);
  await Hive.openBox<Map>('day_plans', encryptionCipher: hiveCipher);
  await Hive.openBox<Map>('analytics_events', encryptionCipher: hiveCipher);

  await NotificationService().init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(currentUser: current),
      child: const PlannerApp(),
    ),
  );
}

class PlannerApp extends StatelessWidget {
  const PlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('settings');
    final hasSeenOnboarding = box.get('seenOnboarding', defaultValue: false) as bool;

    return MaterialApp(
      title: 'Planner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: hasSeenOnboarding ? const MainPage() : const OnboardingPage(),
      routes: {
        LoginPage.routeName: (_) => const LoginPage(),
        SignupPage.routeName: (_) => const SignupPage(),
        AchievementsPage.routeName: (_) => const AchievementsPage(),
        StorePage.routeName: (_) => const StorePage(),
        HabitTrackerPage.routeName: (_) => const HabitTrackerPage(),
        SettingsPage.routeName: (_) => const SettingsPage(),
        JournalPage.routeName: (_) => const JournalPage(),
        SchedulerPage.routeName: (_) => const SchedulerPage(),
        CalendarPage.routeName: (_) => const CalendarPage(),
        ProfilePage.routeName: (_) => const ProfilePage(),
        InboxPage.routeName: (_) => const InboxPage(),
        TodayPage.routeName: (_) => const TodayPage(),

        // ✅ ДОБАВЬ (можно оставить, пригодится для переходов по имени)
        AiCompanionPage.routeName: (_) => const AiCompanionPage(),
      },
    );
  }
}

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
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
                    colors: [AppColors.accent, AppColors.accent.withAlpha((0.72 * 255).round())],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: AppShadows.card,
                ),
                child: const Icon(Icons.auto_awesome_rounded, size: 52, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text(
                'Welcome to Planner!',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              const Text(
                'This app helps you plan and track your daily activities',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.textMuted),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MainPage(),
                      ),
                    );
                  },
                  child: const Text('Start'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  // ✅ 5 страницы
  static const List<Widget> _pages = [
    TodayPage(),
    CalendarPage(),
    ToolsOverviewPage(),
    AiCompanionPage(),
    ProfilePage(),
  ];

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),

      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.xl),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: AppShadows.card,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadii.xl),
              ),
              child: NavigationBar(
                height: 64,
                backgroundColor: Colors.white,
                elevation: 0,
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onNavTap,
                indicatorColor: AppColors.accent.withAlpha((0.14 * 255).round()),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.today_outlined),
                    selectedIcon: Icon(Icons.today_rounded),
                    label: 'Сегодня',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month_rounded),
                    label: 'Календарь',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.apps_outlined),
                    selectedIcon: Icon(Icons.apps_rounded),
                    label: 'Инструменты',
                  ),

                  // ✅ НОВАЯ КНОПКА AI
                  NavigationDestination(
                    icon: Icon(Icons.auto_awesome_outlined),
                    selectedIcon: Icon(Icons.auto_awesome_rounded),
                    label: 'AI',
                  ),

                  NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: 'Профиль',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
