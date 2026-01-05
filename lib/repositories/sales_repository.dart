
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

  Future<SalesStats> getStatsForRange(DateTime start, DateTime end, {String? outletId, String? paymentMethod}) async {
    try {
      if (AppConstants.supabaseUrl.contains('YOUR_SUPABASE_URL')) {
        return SalesStats(totalRevenue: 5400, totalOrders: 12, averageOrderValue: 450);
      }

      var query = _client
          .from('orders')
          .select('total_amount')
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String());

      if (outletId != null) query = query.eq('outlet_id', outletId);
      if (paymentMethod != null) query = query.eq('payment_method', paymentMethod.toLowerCase());

      final response = await query;
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


  Future<List<Map<String, dynamic>>> getRecentOrders({String? outletId, String? paymentMethod, int limit = 10}) async {
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

      var query = _client
          .from('orders')
          .select('id, total_amount, status, customer_name, customer_phone, created_at, payment_method, order_items(quantity, price, menu_items(name))');

      if (outletId != null) query = query.eq('outlet_id', outletId);
      if (paymentMethod != null) query = query.eq('payment_method', paymentMethod.toLowerCase());
      
      final response = await query.order('created_at', ascending: false).limit(limit);
      
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint("Error fetching orders: $e");
      return [];
    }
  }
}

final salesRepositoryProvider = Provider((ref) => SalesRepository());

final dailySalesProvider = FutureProvider<SalesStats>((ref) async {
  return ref.watch(salesRepositoryProvider).getDailyStats();
});

final recentOrdersProvider = Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  return ref.watch(filteredOrdersProvider);
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

class StringFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void setFilter(String? val) => state = val;
}

final outletFilterProvider = NotifierProvider<StringFilterNotifier, String?>(StringFilterNotifier.new);
final paymentMethodFilterProvider = NotifierProvider<StringFilterNotifier, String?>(StringFilterNotifier.new);

final filteredSalesProvider = FutureProvider<SalesStats>((ref) async {
  final range = ref.watch(dateRangeProvider);
  final outletId = ref.watch(outletFilterProvider);
  final paymentMethod = ref.watch(paymentMethodFilterProvider);
  
  return ref.watch(salesRepositoryProvider).getStatsForRange(
    range.start, 
    range.end,
    outletId: outletId,
    paymentMethod: paymentMethod,
  );
});

final filteredOrdersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final outletId = ref.watch(outletFilterProvider);
  final paymentMethod = ref.watch(paymentMethodFilterProvider);
  // Note: we could also add date range to recent orders if needed
  return ref.watch(salesRepositoryProvider).getRecentOrders(
    outletId: outletId,
    paymentMethod: paymentMethod,
  );
});
