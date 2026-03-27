import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../infrastructure/repositories/coupon_repository.dart';
import '../../domain/models/coupon_model.dart';

final couponRepositoryProvider = Provider<CouponRepository>((ref) {
  return CouponRepository(Supabase.instance.client);
});

final allCouponsProvider = FutureProvider<List<CouponModel>>((ref) async {
  final repo = ref.watch(couponRepositoryProvider);
  return repo.getAllCoupons();
});

final activeCouponsProvider = FutureProvider<List<CouponModel>>((ref) async {
  final repo = ref.watch(couponRepositoryProvider);
  return repo.getActiveCoupons();
});

final couponValidatorProvider = Provider.family<Map<String, dynamic>, ({String code, double amount})>((ref, params) {
  final repo = ref.watch(couponRepositoryProvider);
  return {};
});
