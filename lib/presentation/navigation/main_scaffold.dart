import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import '../../core/theme/app_colors.dart';
import '../listening/listening_home_screen.dart';
import '../vocabulary/vocabulary_home_screen.dart';
import '../profile/profile_drive_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    ListeningHomeScreen(),
    VocabularyHomeScreen(),
    ProfileDriveScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return MiuixScaffold(
      containerColor: AppColors.paperBackground,
      bottomBar: MiuixNavigationBar(
        color: AppColors.cardSurface,
        children: [
          MiuixNavigationBarItem(
            selected: _currentIndex == 0,
            onPressed: () => setState(() => _currentIndex = 0),
            icon: const Icon(Icons.headphones_rounded),
            label: '剑雅精听',
          ),
          MiuixNavigationBarItem(
            selected: _currentIndex == 1,
            onPressed: () => setState(() => _currentIndex = 1),
            icon: const Icon(Icons.auto_stories_rounded),
            label: '核心词汇',
          ),
          MiuixNavigationBarItem(
            selected: _currentIndex == 2,
            onPressed: () => setState(() => _currentIndex = 2),
            icon: const Icon(Icons.cloud_sync_rounded),
            label: '云盘档案',
          ),
        ],
      ),
      content: (contentPadding) {
        return Padding(
          padding: EdgeInsets.only(bottom: contentPadding.bottom),
          child: IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
        );
      },
    );
  }
}
