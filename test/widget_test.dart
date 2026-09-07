import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ielts_prep/main.dart';

void main() {
  testWidgets('App renders main scaffold with 3 navigation tabs', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: IeltsPrepApp(),
      ),
    );

    // 等待首帧渲染
    await tester.pumpAndSettle();

    // 验证三大导航 Tab 标签存在
    expect(find.text('剑雅精听'), findsWidgets);
    expect(find.text('核心词汇'), findsWidgets);
    expect(find.text('云盘档案'), findsWidgets);

    // 切换到“核心词汇” Tab
    await tester.tap(find.text('核心词汇').first);
    await tester.pumpAndSettle();

    // 验证词汇页面分段切换器
    expect(find.text('FSRS 记忆卡片'), findsOneWidget);
    expect(find.text('精听生词本'), findsOneWidget);
  });
}
