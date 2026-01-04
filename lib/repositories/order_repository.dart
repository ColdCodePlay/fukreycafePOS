
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';

class OrderRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<String?> createOrder(Map<String, dynamic> orderData) async {
    print('DEBUG: OrderRepository.createOrder called for ${orderData['items']?.length} items');
    try {
      if (AppConstants.supabaseUrl.contains('YOUR_SUPABASE_URL')) {
        print('DEBUG: Using Mock Order Repository (URL contains YOUR_SUPABASE_URL)');
        return 'mock-order-id-123';
      }

      return await _createOrderInternal(orderData).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('DEBUG: OrderRepository.createOrder TIMED OUT after 15s');
          throw Exception('Checkout timed out. Please check your internet connection and Supabase health.');
        },
      );
    } catch (e) {
      print('ERROR: OrderRepository.createOrder failed: $e');
      rethrow;
    }
  }

  Future<String?> _createOrderInternal(Map<String, dynamic> orderData) async {
    // 1. Create Order
    print('DEBUG: Inserting into orders table... outlet_id: ${orderData['outlet_id']}');
    final orderResponse = await _client.from('orders').insert({
      'outlet_id': orderData['outlet_id'],
      'total_amount': orderData['total'],
      'status': 'completed',
      'payment_method': 'cash',
      'coupon_code': orderData['coupon_code'],
      'discount_amount': orderData['discount_amount'],
      'tax_amount': orderData['tax_amount'] ?? 0,
      'customer_name': orderData['customer_name'],
      'customer_phone': orderData['customer_phone'],
    }).select().single();

    final orderId = orderResponse['id'];
    print('DEBUG: Order created with ID: $orderId. Inserting items...');

    // 2. Create Order Items
    final List<Map<String, dynamic>> items = [];
    for (var item in orderData['items']) {
      items.add({
        'order_id': orderId,
        'menu_item_id': item['id'],
        'quantity': item['quantity'],
        'price': item['price'],
      });
    }
    
    if (items.isNotEmpty) {
      print('DEBUG: Inserting ${items.length} items into order_items table...');
      await _client.from('order_items').insert(items);
      print('DEBUG: Order items inserted successfully.');
    }

    return orderId;
  }
}

final orderRepositoryProvider = Provider((ref) => OrderRepository());
