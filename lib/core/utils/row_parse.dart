import 'package:flutter/foundation.dart';

/// 行级容错解析。
///
/// 仓储层把表行转模型时统一走这里：恢复旧版本备份、手工编辑 JSON
/// 都可能造出缺字段的行，原先 `maps.map(Model.fromMap)` 一条坏行
/// 抛异常会让整张表解析失败——页面静默显示空列表，数据还在库里却
/// 不可见。现在只跳过坏行并记日志，其余照常返回。
List<T> parseRows<T>(
  Iterable<Map<String, dynamic>> rows,
  T Function(Map<String, dynamic>) parse,
) {
  final List<T> out = <T>[];
  for (final Map<String, dynamic> row in rows) {
    try {
      out.add(parse(row));
    } catch (e) {
      debugPrint('跳过一条无法解析的记录（$T）: $e');
    }
  }
  return out;
}
