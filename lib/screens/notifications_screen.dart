import 'package:flutter/material.dart';

import '../services/app_localization.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../models/data_models.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotice> _notices = [];
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _markRead() async {
    try {
      final client = SupabaseService.client, user = SupabaseService.currentUser;
      if (client != null && user != null) {
        await client
            .from('app_notifications')
            .update({'is_read': true})
            .eq('user_id', user.id);
      }
      await StorageService.instance.saveNotices(
        _notices
            .map(
              (notice) => AppNotice(
                id: notice.id,
                title: notice.title,
                message: notice.message,
                createdAt: notice.createdAt,
                type: notice.type,
                read: true,
              ),
            )
            .toList(),
      );
      if (mounted) {
        setState(() => _notices = StorageService.instance.loadNotices());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: LocalizedText('Không cập nhật được thông báo: $e')),
        );
      }
    }
  }

  Future<void> _load() async {
    await StorageService.instance.ensureMembershipNotices();
    try {
      final client = SupabaseService.client, user = SupabaseService.currentUser;
      if (client != null && user != null) {
        final rows = await client
            .from('app_notifications')
            .select()
            .eq('user_id', user.id)
            .order('created_at', ascending: false);
        final merged = {
          for (final n in StorageService.instance.loadNotices()) n.id: n,
        };
        for (final row in rows) {
          merged[row['id'] as String] = AppNotice(
            id: row['id'] as String,
            title: row['title'] as String,
            message: row['message'] as String,
            createdAt: DateTime.parse(row['created_at'] as String),
            type: row['notice_type'] as String,
            read: row['is_read'] as bool,
          );
        }
        await StorageService.instance.saveNotices(merged.values.toList());
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) {
      setState(() => _notices = StorageService.instance.loadNotices());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: LocalizedText('Thông báo'),
      actions: [
        TextButton(
          onPressed: _notices.any((notice) => !notice.read) ? _markRead : null,
          child: LocalizedText('Đọc tất cả'),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.all(20),
        children: [
          if (_error != null)
            LocalizedText('Không tải được thông báo: $_error'),
          if (_notices.isEmpty)
            Padding(
              padding: EdgeInsets.all(32),
              child: LocalizedText('Chưa có thông báo'),
            ),
          ..._notices.map(
            (n) => Card(
              child: ListTile(
                leading: Icon(
                  n.type == 'expiry'
                      ? Icons.event_busy
                      : Icons.notifications_outlined,
                ),
                title: LocalizedText(n.title),
                subtitle: LocalizedText(
                  '${n.message}\n${n.createdAt.toLocal()}',
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
