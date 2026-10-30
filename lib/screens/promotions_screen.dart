import 'package:flutter/material.dart';

import '../services/app_localization.dart';
import '../services/supabase_service.dart';

class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});
  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = SupabaseService.client;
      if (client != null) {
        final now = DateTime.now().toUtc().toIso8601String();
        _items = await client
            .from('promotions')
            .select()
            .eq('active', true)
            .lte('starts_at', now)
            .or('ends_at.is.null,ends_at.gte.$now')
            .order('ends_at');
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: LocalizedText('Chương trình khuyến mãi')),
    body: _loading
        ? Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: EdgeInsets.all(20),
              children: [
                if (_error != null)
                  LocalizedText('Không tải được ưu đãi: $_error')
                else if (_items.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: LocalizedText('Chưa có ưu đãi đang hoạt động'),
                  ),
                ..._items.map(
                  (p) => Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.local_offer_outlined),
                          LocalizedText(
                            p['title'] as String,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          LocalizedText(p['description'] as String),
                          LocalizedText(
                            p['ends_at'] == null
                                ? 'Ưu đãi đang áp dụng'
                                : 'Kết thúc: ${p['ends_at']}',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
  );
}
