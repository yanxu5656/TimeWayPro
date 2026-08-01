import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../task/data/repositories/task_repository.dart';
import '../../../task/providers/task_provider.dart';
import '../../../planning/providers/plan_provider.dart';
import '../../models/sync_config.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, provider, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 同步设置
              _buildSection(
                title: '云端同步',
                icon: Icons.cloud_outlined,
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
                title: '数据管理',
                icon: Icons.storage_outlined,
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
                title: '关于',
                icon: Icons.info_outline,
                children: [
                  _buildInfoTile('版本', AppConstants.appVersion),
                  _buildInfoTile('应用名', '${AppConstants.appNameCn} (${AppConstants.appName})'),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: provider.isConfigured
            ? AppColors.success.withOpacity(0.1)
            : AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.isConfigured ? '已连接坚果云' : '未配置同步',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: provider.isConfigured
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                ),
                if (provider.syncConfig?.lastSyncTime != null)
                  Text(
                    '上次同步: ${DateFormat('MM/dd HH:mm').format(provider.syncConfig!.lastSyncTime!)}',
                    style: const TextStyle(
                      fontSize: 12,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _showSyncConfig(BuildContext context, SettingsProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('连接失败: ${provider.syncError ?? "请检查配置"}'),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
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
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
      final success = await provider.restore();
      if (context.mounted) {
        // 重新加载数据
        context.read<TaskProvider>().loadTasks();
        context.read<PlanProvider>().loadPlans();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '恢复成功，请切换到任务页面查看' : '恢复失败: ${provider.syncError}'),
            backgroundColor: success ? AppColors.success : AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _disconnect(
      BuildContext context, SettingsProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('断开连接'),
        content: const Text('确定要断开坚果云连接吗？本地数据不会被删除。'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定断开',
                style: TextStyle(color: AppColors.error)),
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
        fileName: 'time_way_pro_backup_${DateFormat('yyyyMMdd').format(DateTime.now())}.json',
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
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出失败: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          // 重新加载数据
          context.read<TaskProvider>().loadTasks();
          context.read<PlanProvider>().loadPlans();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('导入成功，请切换到任务页面查看'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入失败: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
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
        text: widget.currentConfig?.webdavUrl ?? AppConstants.defaultWebDavUrl);
    _usernameController =
        TextEditingController(text: widget.currentConfig?.username ?? '');
    _passwordController =
        TextEditingController(text: widget.currentConfig?.password ?? '');
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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '配置坚果云同步',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '请先在坚果云中开启WebDAV服务，获取应用密码后填入以下信息。',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
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
                  decoration: const InputDecoration(
                    hintText: '坚果云账号邮箱',
                  ),
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
                  decoration: const InputDecoration(
                    hintText: '坚果云生成的应用密码',
                  ),
                  validator: (v) => v!.isEmpty ? '请输入密码' : null,
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!_formKey.currentState!.validate()) return;
                      widget.onSave(SyncConfig(
                        webdavUrl: _urlController.text.trim(),
                        username: _usernameController.text.trim(),
                        password: _passwordController.text.trim(),
                      ));
                    },
                    child: const Text('保存并测试连接'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
