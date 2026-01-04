
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../core/constants.dart';

class SalesStats {
  final double totalRevenue;
  final int totalOrders;
  final double averageOrderValue;

  SalesStats({
    required this.totalRevenue,
    required this.totalOrders,
    required this.averageOrderValue,
  });
}

class SalesRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<SalesStats> getDailyStats() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return getStatsForRange(start, end);
  }

  Future<SalesStats> getStatsForRange(DateTime start, DateTime end) async {
    try {
      if (AppConstants.supabaseUrl.contains('YOUR_SUPABASE_URL')) {
        return SalesStats(totalRevenue: 5400, totalOrders: 12, averageOrderValue: 450);
      }

      final response = await _client
          .from('orders')
          .select('total_amount')
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String());

      final List<dynamic> data = response as List<dynamic>;

      if (data.isEmpty) {
        return SalesStats(totalRevenue: 0, totalOrders: 0, averageOrderValue: 0);
      }

      double totalRevenue = 0;
      for (var order in data) {
        totalRevenue += (order['total_amount'] as num).toDouble();
      }

      return SalesStats(
        totalRevenue: totalRevenue,
        totalOrders: data.length,
        averageOrderValue: totalRevenue / data.length,
      );
    } catch (e) {
      return SalesStats(totalRevenue: 0, totalOrders: 0, averageOrderValue: 0);
    }
  }


  Future<List<Map<String, dynamic>>> getRecentOrders() async {
     try {
      if (AppConstants.supabaseUrl.contains('YOUR_SUPABASE_URL')) {
        return [
          {
            'id': '1234', 
            'total_amount': 450, 
            'status': 'completed', 
            'customer_name': 'John Doe',
            'created_at': DateTime.now().subtract(const Duration(minutes: 5)).toString(),
            'order_items': [{'quantity': 2, 'price': 225, 'menu_items': {'name': 'Pizza'}}]
          },
        ];
      }

      final response = await _client
          .from('orders')
          .select('*, order_items(*, menu_items(name))')
          .order('created_at', ascending: false)
          .limit(10);
      
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      return [];
    }
  }
}

final salesRepositoryProvider = Provider((ref) => SalesRepository());

final dailySalesProvider = FutureProvider<SalesStats>((ref) async {
  return ref.watch(salesRepositoryProvider).getDailyStats();
});

final recentOrdersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(salesRepositoryProvider).getRecentOrders();
});

class DateRangeNotifier extends Notifier<DateTimeRange> {
  @override
  DateTimeRange build() {
    final now = DateTime.now();
    return DateTimeRange(
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }
  void setRange(DateTimeRange range) => state = range;
}

final dateRangeProvider = NotifierProvider<DateRangeNotifier, DateTimeRange>(DateRangeNotifier.new);

final filteredSalesProvider = FutureProvider<SalesStats>((ref) async {
  final range = ref.watch(dateRangeProvider);
  return ref.watch(salesRepositoryProvider).getStatsForRange(range.start, range.end);
});
