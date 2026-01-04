
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final userRepositoryProvider = Provider((ref) => UserRepository(Supabase.instance.client));

class UserModel {
  final String id;
  final String email;
  final String role; // 'admin' or 'staff'
  final String? outletId;

  UserModel({
    required this.id,
    required this.email,
    required this.role,
    this.outletId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'] ?? '',
      role: json['role'] ?? 'staff',
      outletId: json['outlet_id'],
    );
  }
}

class UserRepository {
  final SupabaseClient _supabase;

  UserRepository(this._supabase);

  Future<UserModel?> getUserProfile(String userId) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data == null) return null;
      return UserModel.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  Future<List<UserModel>> getAllUsers() async {
    try {
      final List<dynamic> data = await _supabase
          .from('profiles')
          .select()
          .order('email');
      
      return data.map((e) => UserModel.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> updateUser(String userId, {required String role, String? outletId}) async {
    await _supabase.from('profiles').update({
      'role': role,
      'outlet_id': outletId,
    }).eq('id', userId);
  }
}

final allUsersProvider = FutureProvider<List<UserModel>>((ref) async {
  return ref.watch(userRepositoryProvider).getAllUsers();
});

final outletsRepoProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  final data = await supabase.from('outlets').select();
  return List<Map<String, dynamic>>.from(data);
});
