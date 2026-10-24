import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/core/ui/paper.dart';

/// 下划线分段控件的回归测试。
///
/// 重点是颜色：v1.5.0 迁移时未选中标签被误降到 textHint（2.7:1），
/// 13px 的可点文字用这个色违反设计系统的对比度硬规则——
/// 这个测试就是防它再犯。
void main() {
  Widget host({required int value, required ValueChanged<int> onChanged}) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Center(
          child: SegmentedControl<int>(
            segments: const <Segment<int>>[
              Segment<int>(0, '日'),
              Segment<int>(1, '周'),
              Segment<int>(2, '月'),
            ],
            value: value,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  testWidgets('渲染全部分段并回调切换', (tester) async {
    int? selected;
    await tester.pumpWidget(host(value: 1, onChanged: (v) => selected = v));

    expect(find.text('日'), findsOneWidget);
    expect(find.text('周'), findsOneWidget);
    expect(find.text('月'), findsOneWidget);

    await tester.tap(find.text('月'));
    expect(selected, 2);
  });

  testWidgets('未选中标签不使用 textHint（对比度硬规则）', (tester) async {
    await tester.pumpWidget(host(value: 1, onChanged: (_) {}));
    await tester.pumpAndSettle();

    final TextStyle inactive = tester.widget<Text>(find.text('日')).style!;
    final TextStyle active = tester.widget<Text>(find.text('周')).style!;

    expect(
      inactive.color,
      AppColors.textSecondary,
      reason: '13px 的可点文字不得用 textHint（2.7:1，仅限装饰）',
    );
    expect(active.color, AppColors.textPrimary);
    expect(active.fontWeight, FontWeight.w700);
  });

  testWidgets('选中态切换后样式跟着换', (tester) async {
    int value = 1;
    Widget build() => host(value: value, onChanged: (v) => value = v);
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    await tester.tap(find.text('月'));
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.text('月')).style!.color,
        AppColors.textPrimary);
    expect(tester.widget<Text>(find.text('日')).style!.color,
        AppColors.textSecondary);
  });
}
