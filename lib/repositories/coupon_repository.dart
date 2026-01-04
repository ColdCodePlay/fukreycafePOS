
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/coupon_model.dart';

final couponRepositoryProvider = Provider((ref) => CouponRepository(Supabase.instance.client));

class CouponRepository {
  final SupabaseClient _supabase;

  CouponRepository(this._supabase);

  Future<CouponModel?> getCouponByCode(String code) async {
    try {
      final data = await _supabase
          .from('coupons')
          .select()
          .eq('code', code.toUpperCase())
          .eq('is_active', true)
          .maybeSingle();

      if (data == null) return null;
      return CouponModel.fromJson(data);
    } catch (e) {
      return null;
    }
  }
}
