import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../../core/ui/paper.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/services/notification_service.dart';
import '../../../task/data/repositories/task_repository.dart';
import '../../../task/providers/task_provider.dart';
import '../../../planning/providers/plan_provider.dart';
import '../../../daily/providers/daily_provider.dart';
import '../../../weekly/providers/weekly_provider.dart';
import '../../../leisure/providers/leisure_provider.dart';
import '../../../calendar/providers/calendar_provider.dart';
import '../../models/sync_config.dart';
import '../../providers/theme_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/theme_picker.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PaperScaffold(
      body: Consumer2<SettingsProvider, ThemeProvider>(
        builder: (context, provider, themeProvider, child) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.xs,
              AppSpacing.screenH,
              AppSpacing.navInset,
            ),
            children: [
              const Masthead(kicker: 'SETTINGS', title: '设置'),
              const SizedBox(height: AppSpacing.md),

              _buildSection(
                context,
                index: 1,
                title: '外观主题',
                trailing: themeProvider.option.name,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    child: Text(
                      '点击方案即可实时切换并自动保存。简洁、可爱、科技各提供 3 款，原有功能与数据不受影响。',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                  ThemePicker(),
                ],
              ),
              const SizedBox(height: 20),

              // 同步设置
              _buildSection(
                context,
                index: 2,
                title: '云端同步',
                trailing: provider.isConfigured ? '已连接' : '未配置',
                children: [
                  _buildSyncStatus(context, provider),
                  const SizedBox(height: 12),
                  if (!provider.isConfigured)
                    _buildSyncConfigButton(context)
                  else ...[
                    _buildSyncAction(
                      context,
                      icon: Icons.backup_outlined,
                      title: '立即备份',
                      subtitle: '将数据上传到坚果云',
                      onTap: () => _backup(context, provider),
                    ),
                    _buildSyncAction(
                      context,
                      icon: Icons.restore_outlined,
                      title: '恢复数据',
                      subtitle: '从坚果云下载数据',
                      onTap: () => _restore(context, provider),
                    ),
                    _buildSyncAction(
                      context,
                      icon: Icons.settings_outlined,
                      title: '重新配置',
                      subtitle: '修改坚果云账号信息',
                      onTap: () => _showSyncConfig(context, provider),
                    ),
                    _buildSyncAction(
                      context,
                      icon: Icons.link_off_outlined,
                      title: '断开连接',
                      subtitle: '移除坚果云绑定',
                      color: context.colors.error,
                      onTap: () => _disconnect(context, provider),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),

              // 数据管理
              _buildSection(
                context,
                index: 3,
                title: '数据管理',
                children: [
                  _buildSyncAction(
                    context,
                    icon: Icons.upload_outlined,
                    title: '导出数据',
                    subtitle: '导出为JSON文件',
                    onTap: () => _exportData(context),
                  ),
                  _buildSyncAction(
                    context,
                    icon: Icons.download_outlined,
                    title: '导入数据',
                    subtitle: '从JSON文件导入',
                    onTap: () => _importData(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 关于
              _buildSection(
                context,
                index: 4,
                title: '关于',
                trailing: 'v${AppConstants.appVersion}',
                children: [
                  _buildInfoTile(context, '版本', AppConstants.appVersion),
                  _buildInfoTile(
                    context,
                    '应用名',
                    '${AppConstants.appNameCn} (${AppConstants.appName})',
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required int index,
    required String title,
    String? trailing,
    required List<Widget> children,
  }) {
    return PaperCard(
      // 内部自己排版，标题与列表项各自带内边距
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  index.toString().padLeft(2, '0'),
                  style: context.text.serifNum.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.colors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  title,
                  style: AppText.label.copyWith(
                    fontSize: 13,
                    letterSpacing: 2.4,
                    color: context.colors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (trailing != null)
                  Text(
                    trailing,
                    style: AppText.caption.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSyncStatus(BuildContext context, SettingsProvider provider) {
    return PaperCard(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm),
      // 浮起白卡（raised 档）：它嵌套在外层分区卡之内，纸面体系的
      // 嵌套层次靠「浮起」表达——白底 + 微影 + success 细描边（tint
      // 在 raised 档才生效；ruled 档会把 fill 画成色块并叠加双线）
      tone: PaperTone.raised,
      // 已连接时描边走 success 强调色
      tint: provider.isConfigured ? context.colors.success : null,
      fill: provider.isConfigured ? null : context.colors.surfaceVariant,
      child: Row(
        children: [
          Icon(
            provider.isConfigured
                ? Icons.cloud_done_outlined
                : Icons.cloud_off_outlined,
            color: provider.isConfigured
                ? context.colors.success
                : context.colors.textHint,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.isConfigured ? '已连接坚果云' : '未配置同步',
                  style: AppText.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: provider.isConfigured
                        ? context.colors.success
                        : context.colors.textSecondary,
                  ),
                ),
                if (provider.syncConfig?.lastSyncTime != null)
                  Text(
                    '上次同步: ${DateFormat('MM/dd HH:mm').format(provider.syncConfig!.lastSyncTime!)}',
                    style: AppText.caption.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (provider.isSyncing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildSyncConfigButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(Icons.add_circle_outline, color: context.colors.primary),
        title: const Text('配置坚果云同步'),
        subtitle: const Text('使用WebDAV同步到坚果云'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          final provider = context.read<SettingsProvider>();
          _showSyncConfig(context, provider);
        },
      ),
    );
  }

  Widget _buildSyncAction(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: color ?? context.colors.textPrimary),
        title: Text(title, style: TextStyle(color: color)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppText.body.copyWith(color: context.colors.textSecondary),
          ),
          Text(
            value,
            style: AppText.body.copyWith(color: context.colors.textPrimary),
          ),
        ],
      ),
    );
  }

  void _showSyncConfig(BuildContext context, SettingsProvider provider) {
    showPaperSheet(
      context,
      builder: (context) => _SyncConfigSheet(
        currentConfig: provider.syncConfig,
        onSave: (config) async {
          final success = await provider.saveSyncConfig(config);
          if (context.mounted) {
            if (success) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('连接成功'),
                  backgroundColor: context.colors.success,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('连接失败: ${provider.syncError ?? "请检查配置"}'),
                  backgroundColor: context.colors.error,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _backup(BuildContext context, SettingsProvider provider) async {
    final success = await provider.backup();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '备份成功' : '备份失败: ${provider.syncError}'),
          backgroundColor: success
              ? context.colors.success
              : context.colors.error,
        ),
      );
    }
  }

  Future<void> _restore(BuildContext context, SettingsProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复数据'),
        content: const Text('恢复将覆盖当前所有数据，确定继续吗？'),
        actions: [
          PaperTextButton(
            onPressed: () => Navigator.pop(context, false),
            label: '取消',
          ),
          PaperTextButton(
            onPressed: () {
              AppHaptics.confirm();
              Navigator.pop(context, true);
            },
            label: '确定恢复',
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      final taskProvider = context.read<TaskProvider>();
      List<TimerState>? suspendedTimers;
      // 下载与解析成功后才停表；网络失败不应打断用户正在进行的计时。
      final success = await provider.restore(
        beforeImport: () async {
          final List<TimerState> stopped = await taskProvider
              .stopAllTimersForDataReset();
          suspendedTimers = stopped;
          return stopped;
        },
      );
      if (!context.mounted) return;
      if (success) {
        await _reloadDataProviders(context);
      } else {
        final List<TimerState>? stopped = suspendedTimers;
        if (stopped != null) {
          await taskProvider.restoreTimersAfterFailedDataReset(stopped);
        }
        await NotificationService().syncTaskReminders(taskProvider.tasks);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? '恢复成功，数据已全部刷新' : '恢复失败: ${provider.syncError}',
            ),
            backgroundColor: success
                ? context.colors.success
                : context.colors.error,
          ),
        );
      }
    }
  }

  Future<void> _reloadDataProviders(BuildContext context) async {
    await Future.wait(<Future<void>>[
      context.read<TaskProvider>().loadTasks(),
      context.read<PlanProvider>().loadPlans(),
      context.read<DailyProvider>().loadTasks(),
      context.read<WeeklyProvider>().loadGoals(),
      context.read<LeisureProvider>().loadItems(),
      context.read<CalendarProvider>().loadMonth(),
      context.read<SettingsProvider>().loadSyncConfig(),
    ]);
  }

  Future<void> _disconnect(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('断开连接'),
        content: const Text('确定要断开坚果云连接吗？本地数据不会被删除。'),
        actions: [
          PaperTextButton(
            onPressed: () => Navigator.pop(context, false),
            label: '取消',
          ),
          PaperTextButton(
            onPressed: () {
              AppHaptics.confirm();
              Navigator.pop(context, true);
            },
            color: context.colors.error,
            label: '确定断开',
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.clearSyncConfig();
    }
  }

  Future<void> _exportData(BuildContext context) async {
    try {
      final repo = TaskRepository();
      final data = await repo.exportAllData();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

      final result = await FilePicker.platform.saveFile(
        dialogTitle: '导出数据',
        fileName:
            'time_way_pro_backup_${DateFormat('yyyyMMdd').format(DateTime.now())}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final file = File(result);
        await file.writeAsString(jsonStr);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('导出成功'),
              backgroundColor: context.colors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出失败: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  Future<void> _importData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入数据'),
        content: const Text('导入将覆盖当前所有数据，确定继续吗？'),
        actions: [
          PaperTextButton(
            onPressed: () => Navigator.pop(context, false),
            label: '取消',
          ),
          PaperTextButton(
            onPressed: () {
              AppHaptics.confirm();
              Navigator.pop(context, true);
            },
            label: '确定导入',
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    TaskProvider? resetProvider;
    List<TimerState>? suspendedTimers;
    bool imported = false;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonStr = await file.readAsString();
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;

        final repo = TaskRepository();
        repo.validateAllData(data);
        if (!context.mounted) return;
        // 必须先停表再替换数据，避免在途计时把旧会话写进刚导入的新数据集。
        resetProvider = context.read<TaskProvider>();
        suspendedTimers = await resetProvider.stopAllTimersForDataReset();
        await repo.importAllData(data);
        imported = true;

        if (context.mounted) {
          await _reloadDataProviders(context);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('导入成功，数据已全部刷新'),
                backgroundColor: context.colors.success,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (resetProvider != null && !imported) {
        final List<TimerState>? stopped = suspendedTimers;
        if (stopped != null) {
          await resetProvider.restoreTimersAfterFailedDataReset(stopped);
        }
        await NotificationService().syncTaskReminders(resetProvider.tasks);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入失败: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }
}

class _SyncConfigSheet extends StatefulWidget {
  final SyncConfig? currentConfig;
  final Future<void> Function(SyncConfig) onSave;

  const _SyncConfigSheet({required this.currentConfig, required this.onSave});

  @override
  State<_SyncConfigSheet> createState() => _SyncConfigSheetState();
}

class _SyncConfigSheetState extends State<_SyncConfigSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _urlController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;

  /// 连接测试是网络请求，可能走几秒——按钮自己显示进度，
  /// 而不是让用户对着没反应的「保存」反复点。
  bool _saving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        SyncConfig(
          webdavUrl: _urlController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text.trim(),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: widget.currentConfig?.webdavUrl ?? AppConstants.defaultWebDavUrl,
    );
    _usernameController = TextEditingController(
      text: widget.currentConfig?.username ?? '',
    );
    _passwordController = TextEditingController(
      text: widget.currentConfig?.password ?? '',
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 外层 Padding(viewInsets) / SafeArea / SingleChildScrollView / 拖拽把手
    // 全部由 PaperSheet 提供，这里只负责表单本身。
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '配置坚果云同步',
            style: context.text.titleSerif.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请先在坚果云中开启WebDAV服务，获取应用密码后填入以下信息。',
            style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
          ),
          const SizedBox(height: 20),

          // WebDAV地址
          Text(
            'WebDAV地址',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _urlController,
            decoration: const InputDecoration(
              hintText: 'https://dav.jianguoyun.com/dav/',
            ),
            validator: (v) => v!.isEmpty ? '请输入WebDAV地址' : null,
          ),
          const SizedBox(height: 16),

          // 用户名
          Text(
            '用户名',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(hintText: '坚果云账号邮箱'),
            validator: (v) => v!.isEmpty ? '请输入用户名' : null,
          ),
          const SizedBox(height: 16),

          // 密码
          Text(
            '应用密码',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(hintText: '坚果云生成的应用密码'),
            validator: (v) => v!.isEmpty ? '请输入密码' : null,
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: PaperButton(
              onPressed: _save,
              loading: _saving,
              loadingLabel: '连接测试中…',
              label: '保存并测试连接',
            ),
          ),
        ],
      ),
    );
  }
}
