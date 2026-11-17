import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/core/ui/paper.dart';

/// 纸感按钮家族的回归测试。
///
/// 最重要的一条：包装件内部**必须仍是真正的 Material 按钮**——
/// 全项目既有测试用 `find.widgetWithText(ElevatedButton, '添加')`
/// 这类 finder 定位按钮，包装件若换成自绘容器会让它们全部失明。
Widget _host(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppTheme.lightTheme,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  setUp(UiEffects.resetForTesting);

  testWidgets('内部仍是真 ElevatedButton，既有 finder 不受影响', (tester) async {
    await tester.pumpWidget(
      _host(PaperButton(label: '添加', onPressed: () {})),
    );

    expect(find.widgetWithText(ElevatedButton, '添加'), findsOneWidget);
    expect(find.byType(PressableScale), findsOneWidget);
  });

  testWidgets('次按钮 / 文字按钮同样保留真身', (tester) async {
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PaperOutlinedButton(label: '仅关闭闹铃', onPressed: () {}),
            PaperTextButton(label: '取消', onPressed: () {}),
          ],
        ),
      ),
    );

    expect(
      find.widgetWithText(OutlinedButton, '仅关闭闹铃'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, '取消'), findsOneWidget);
  });

  testWidgets('点击触发回调', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(PaperButton(label: '添加', onPressed: () => taps++)),
    );

    await tester.tap(find.byType(PaperButton));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('onPressed 为 null 时禁用', (tester) async {
    await tester.pumpWidget(_host(const PaperButton(label: '添加')));

    final ElevatedButton button = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('loading：显示进度环与替换文案，且点击被禁用', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        PaperButton(
          label: '保存并测试连接',
          loading: true,
          loadingLabel: '连接测试中…',
          onPressed: () => taps++,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('连接测试中…'), findsOneWidget);
    expect(find.text('保存并测试连接'), findsNothing);

    final ElevatedButton button = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    expect(button.onPressed, isNull, reason: 'loading 期间不得响应点击');

    await tester.tap(find.byType(PaperButton), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(taps, 0);
  });

  testWidgets('文案变化走 AnimatedSwitcher 形变，落定后显示新文案', (tester) async {
    await tester.pumpWidget(
      _host(PaperButton(label: '暂停', onPressed: () {})),
    );
    expect(find.byType(AnimatedSwitcher), findsWidgets);

    await tester.pumpWidget(
      _host(PaperButton(label: '继续专注', onPressed: () {})),
    );
    // 形变进行中：新旧文案短暂共存
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(find.text('暂停'), findsOneWidget);
    expect(find.text('继续专注'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('暂停'), findsNothing);
    expect(find.text('继续专注'), findsOneWidget);
  });

  testWidgets('图标变化同样走形变', (tester) async {
    await tester.pumpWidget(
      _host(
        PaperButton(
          label: '计时',
          icon: Icons.pause_rounded,
          onPressed: () {},
        ),
      ),
    );
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    await tester.pumpWidget(
      _host(
        PaperButton(
          label: '计时',
          icon: Icons.play_arrow_rounded,
          onPressed: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.pause_rounded), findsNothing);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('compact 档比默认档矮（横幅 / 弹窗行内用）', (tester) async {
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PaperButton(key: const Key('normal'), label: '默认', onPressed: () {}),
            PaperButton(
              key: const Key('compact'),
              label: '紧凑',
              compact: true,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );

    final double normal = tester.getSize(find.byKey(const Key('normal'))).height;
    final double compact = tester
        .getSize(find.byKey(const Key('compact')))
        .height;
    expect(compact, lessThan(normal));
  });

  testWidgets('文字按钮可传错误色（删除动作）', (tester) async {
    await tester.pumpWidget(
      _host(
        PaperTextButton(label: '删除', color: AppColors.error, onPressed: () {}),
      ),
    );

    final TextButton button = tester.widget<TextButton>(
      find.byType(TextButton),
    );
    expect(button.style?.foregroundColor?.resolve(<WidgetState>{}), AppColors.error);
  });
}