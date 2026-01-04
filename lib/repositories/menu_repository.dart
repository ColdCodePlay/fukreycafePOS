
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/menu_item_model.dart';
import '../core/constants.dart';

class MenuRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<MenuItem>> getMenuItems() async {
    try {
      // Return mock data if url is placeholder
      if (AppConstants.supabaseUrl.contains('YOUR_SUPABASE_URL')) {
        return [
          MenuItem(id: '1', name: 'Burger', price: 150, description: 'Tasty burger'),
          MenuItem(id: '2', name: 'Fries', price: 80, description: 'Crispy fries'),
          MenuItem(id: '3', name: 'Coke', price: 40, description: 'Chilled coke'),
        ];
      }
      
      final response = await _client.from('menu_items').select().eq('is_available', true);
      return (response as List).map((e) => MenuItem.fromJson(e)).toList();
    } catch (e) {
      // return empty list or rethrow
      return [];
    }
  }
}

final menuRepositoryProvider = Provider((ref) => MenuRepository());

final menuItemsProvider = FutureProvider<List<MenuItem>>((ref) async {
  return ref.watch(menuRepositoryProvider).getMenuItems();
});

final categoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  final response = await supabase.from('categories').select();
  return List<Map<String, dynamic>>.from(response as List);
});
