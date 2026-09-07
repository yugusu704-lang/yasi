import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_miuix/miuix.dart';
import 'core/theme/miuix_theme_data.dart';
import 'core/theme/app_colors.dart';
import 'presentation/navigation/main_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: IeltsPrepApp(),
    ),
  );
}

class IeltsPrepApp extends StatelessWidget {
  const IeltsPrepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MiuixTheme(
      data: AppMiuixTheme.lightTheme(),
      child: MaterialApp(
        title: '雅思精听备考',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.paperBackground,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.ieltsCrimson,
            surface: AppColors.paperBackground,
            primary: AppColors.ieltsCrimson,
          ),
        ),
        home: const MainScaffold(),
      ),
    );
  }
}
