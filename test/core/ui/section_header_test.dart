import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/core/ui/paper.dart';

/// 编排精修（v1.6.0）两个新排版组件的回归测试。
void main() {
  Widget host(Widget child) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    home: Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(child: child),
    ),
  );

  group('SectionHeader', () {
    testWidgets('渲染序号 / 标题 / 右侧计数', (tester) async {
      await tester.pumpWidget(
        host(
          const SectionHeader(index: 1, title: '本周记事', trailing: '3 条'),
        ),
      );

      expect(find.text('01'), findsOneWidget);
      expect(find.text('本周记事'), findsOneWidget);
      expect(find.text('3 条'), findsOneWidget);
    });

    testWidgets('rule:true 画重规线，rule:false 不画', (tester) async {
      await tester.pumpWidget(
        host(
          const Column(
            children: <Widget>[
              SectionHeader(index: 1, title: '有线'),
              SectionHeader(index: 2, title: '无线', rule: false),
            ],
          ),
        ),
      );

      // 重规线是 dividerStrong 的实色 Container：全页应恰好一条
      expect(
        find.byWidgetPredicate(
          (Widget w) => w is Container && w.color == AppColors.dividerStrong,
        ),
        findsOneWidget,
      );
    });

    testWidgets('序号补零到两位', (tester) async {
      await tester.pumpWidget(host(const SectionHeader(index: 3, title: 'x')));
      expect(find.text('03'), findsOneWidget);
    });
  });

  group('Masthead 水印与元信息', () {
    testWidgets('ghost 渲染且不抛异常（溢出被 Stack 裁切）', (tester) async {
      await tester.pumpWidget(
        host(
          const Padding(
            padding: EdgeInsets.all(20),
            child: Masthead(
              kicker: 'WEEKLY LEDGER',
              title: '每周目标',
              ghost: '44',
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('44'), findsOneWidget);
    });

    testWidgets('meta 行渲染在标题与铅线之间', (tester) async {
      await tester.pumpWidget(
        host(
          const Padding(
            padding: EdgeInsets.all(20),
            child: Masthead(
              kicker: 'DAILY LIST',
              title: '每日待办',
              meta: Text('2026 年 10 月 · 第 44 周 · 共 3 条'),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('2026 年 10 月 · 第 44 周 · 共 3 条'), findsOneWidget);
    });
  });
}
