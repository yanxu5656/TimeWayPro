import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../../core/ui/paper.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../task/data/repositories/task_repository.dart';
import '../../../task/providers/task_provider.dart';
import '../../../planning/providers/plan_provider.dart';
import '../../../daily/providers/daily_provider.dart';
import '../../../weekly/providers/weekly_provider.dart';
import '../../models/sync_config.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PaperScaffold(
      body: Consumer<SettingsProvider>(
        builder: (context, provider, child) {
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

              // 同步设置
              _buildSection(
                index: 1,
                title: '云端同步',
                trailing: provider.isConfigured ? '已连接' : '未配置',
                children: [
                  _buildSyncStatus(provider),
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
                      color: AppColors.error,
                      onTap: () => _disconnect(context, provider),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),

              // 数据管理
              _buildSection(
                index: 2,
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
                index: 3,
                title: '关于',
                trailing: 'v${AppConstants.appVersion}',
                children: [
                  _buildInfoTile('版本', AppConstants.appVersion),
                  _buildInfoTile(
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

  Widget _buildSection({
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
                  '${index}'.padLeft(2, '0'),
                  style: AppText.serifNum.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  title,
                  style: AppText.label.copyWith(
                    fontSize: 13,
                    letterSpacing: 2.4,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (trailing != null)
                  Text(
                    trailing,
                    style: AppText.caption.copyWith(
                      color: AppColors.textSecondary,
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

  Widget _buildSyncStatus(SettingsProvider provider) {
    return PaperCard(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm),
      // 浮起白卡（raised 档）：它嵌套在外层分区卡之内，纸面体系的
      // 嵌套层次靠「浮起」表达——白底 + 微影 + success 细描边（tint
      // 在 raised 档才生效；ruled 档会把 fill 画成色块并叠加双线）
      tone: PaperTone.raised,
      // 已连接时描边走 success 强调色
      tint: provider.isConfigured ? AppColors.success : null,
      fill: provider.isConfigured ? null : AppColors.surfaceVariant,
      child: Row(
        children: [
          Icon(
            provider.isConfigured
                ? Icons.cloud_done_outlined
                : Icons.cloud_off_outlined,
            color: provider.isConfigured
                ? AppColors.success
                : AppColors.textHint,
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
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                ),
                if (provider.syncConfig?.lastSyncTime != null)
                  Text(
                    '上次同步: ${DateFormat('MM/dd HH:mm').format(provider.syncConfig!.lastSyncTime!)}',
                    style: AppText.caption.copyWith(
                      color: AppColors.textSecondary,
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
        leading: const Icon(Icons.add_circle_outline, color: AppColors.primary),
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
        leading: Icon(icon, color: color ?? AppColors.textPrimary),
        title: Text(title, style: TextStyle(color: color)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
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
            style: AppText.body.copyWith(color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: AppText.body.copyWith(color: AppColors.textPrimary),
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
                  backgroundColor: AppColors.success,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('连接失败: ${provider.syncError ?? "请检查配置"}'),
                  backgroundColor: AppColors.error,
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
          backgroundColor: success ? AppColors.success : AppColors.error,
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定恢复'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 先停表：恢复会整体替换数据，在途会话的记录随旧数据一起消失，
      // 不停表的话 recordId 会指向新数据集里不存在的记录
      await context.read<TaskProvider>().stopAllTimersForDataReset();

      final success = await provider.restore();
      if (context.mounted) {
        // 四个数据 provider 全部重载（原先只刷了任务/规划——
        // IndexedStack 保活页面，待办/每周页会继续显示旧数据）
        await Future.wait(<Future<void>>[
          context.read<TaskProvider>().loadTasks(),
          context.read<PlanProvider>().loadPlans(),
          context.read<DailyProvider>().loadTasks(),
          context.read<WeeklyProvider>().loadGoals(),
        ]);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success ? '恢复成功，数据已全部刷新' : '恢复失败: ${provider.syncError}',
              ),
              backgroundColor: success ? AppColors.success : AppColors.error,
            ),
          );
        }
      }
    }
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定断开', style: TextStyle(color: AppColors.error)),
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
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e'), backgroundColor: AppColors.error),
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定导入'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

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
        await repo.importAllData(data);

        if (context.mounted) {
          // 与恢复同路径：停表 + 四个 provider 全部重载
          await context.read<TaskProvider>().stopAllTimersForDataReset();
          await Future.wait(<Future<void>>[
            context.read<TaskProvider>().loadTasks(),
            context.read<PlanProvider>().loadPlans(),
            context.read<DailyProvider>().loadTasks(),
            context.read<WeeklyProvider>().loadGoals(),
          ]);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('导入成功，数据已全部刷新'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

class _SyncConfigSheet extends StatefulWidget {
  final SyncConfig? currentConfig;
  final Function(SyncConfig) onSave;

  const _SyncConfigSheet({required this.currentConfig, required this.onSave});

  @override
  State<_SyncConfigSheet> createState() => _SyncConfigSheetState();
}

class _SyncConfigSheetState extends State<_SyncConfigSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _urlController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;

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
            style: AppText.titleSerif.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            '请先在坚果云中开启WebDAV服务，获取应用密码后填入以下信息。',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // WebDAV地址
          const Text(
            'WebDAV地址',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
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
          const Text(
            '用户名',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
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
          const Text(
            '应用密码',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
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
            child: ElevatedButton(
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                widget.onSave(
                  SyncConfig(
                    webdavUrl: _urlController.text.trim(),
                    username: _usernameController.text.trim(),
                    password: _passwordController.text.trim(),
                  ),
                );
              },
              child: const Text('保存并测试连接'),
            ),
          ),
        ],
      ),
    );
  }
}
